#import "MetalRenderer.h"
#import <mach/mach_time.h>
#include <stdio.h>

@implementation CRTMetalRenderer {
    id<MTLComputePipelineState> _computePipeline;
    id<MTLBuffer> _uniformBuffer;
    CRTUniforms _uniforms;

    // Texture cache for efficient CVPixelBuffer -> MTLTexture conversion
    CVMetalTextureCacheRef _textureCache;

    // Performance tracking
    uint64_t _frameCount;
    uint64_t _lastFPSTime;
    float _fps;
    float _latencyMs;
    mach_timebase_info_data_t _timebaseInfo;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        _isReady = NO;

        // Create texture cache for CVPixelBuffer -> MTLTexture conversion
        CVReturn result = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                                     nil,
                                                     device,
                                                     nil,
                                                     &_textureCache);
        if (result != kCVReturnSuccess) {
            NSLog(@"[CRT] Failed to create texture cache: %d", result);
            return nil;
        }

        // Create uniform buffer
        _uniformBuffer = [device newBufferWithLength:sizeof(CRTUniforms)
                                             options:MTLResourceStorageModeShared];

        // Initialize default uniforms
        _uniforms = (CRTUniforms){
            .scanlineWeight = 6.0f,
            .scanlineGap = 0.12f,
            .maskBrightness = 0.75f,
            .maskType = 1,
            .bloomFactor = 1.5f,
            .inputGamma = 2.4f,
            .outputGamma = 2.2f,
            ._padding = 0.0f
        };
        memcpy(_uniformBuffer.contents, &_uniforms, sizeof(CRTUniforms));

        // Performance tracking
        _frameCount = 0;
        _lastFPSTime = mach_absolute_time();
        _fps = 0;
        _latencyMs = 0;
        mach_timebase_info(&_timebaseInfo);
    }
    return self;
}

- (void)dealloc {
    if (_textureCache) {
        CFRelease(_textureCache);
    }
}

- (BOOL)loadShaderFromSource:(NSString *)source error:(NSError **)error {
    MTLCompileOptions *options = [[MTLCompileOptions alloc] init];
    if (@available(macOS 15.0, *)) {
        options.mathMode = MTLMathModeFast;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        options.fastMathEnabled = YES;
#pragma clang diagnostic pop
    }

    id<MTLLibrary> library = [_device newLibraryWithSource:source
                                                   options:options
                                                     error:error];
    if (!library) {
        NSLog(@"[CRT] Shader compilation failed: %@", *error);
        return NO;
    }

    id<MTLFunction> kernelFunction = [library newFunctionWithName:@"processCRT"];
    if (!kernelFunction) {
        if (error) {
            *error = [NSError errorWithDomain:@"CRTMetalRenderer"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Kernel function 'processCRT' not found"}];
        }
        return NO;
    }

    NSError *pipelineError = nil;
    _computePipeline = [_device newComputePipelineStateWithFunction:kernelFunction
                                                              error:&pipelineError];
    if (!_computePipeline) {
        if (error) *error = pipelineError;
        return NO;
    }

    _isReady = YES;
    NSLog(@"[CRT] Shader loaded successfully");
    return YES;
}

- (BOOL)loadShaderFromFile:(NSString *)path error:(NSError **)error {
    NSString *source = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:error];
    if (!source) {
        return NO;
    }
    return [self loadShaderFromSource:source error:error];
}

- (void)updateUniforms:(CRTUniforms)uniforms {
    _uniforms = uniforms;
    memcpy(_uniformBuffer.contents, &_uniforms, sizeof(CRTUniforms));
}

- (void)setUniformFloat:(NSString *)name value:(float)value {
    if ([name isEqualToString:@"scanline-weight"] || [name isEqualToString:@"scanlineWeight"]) {
        _uniforms.scanlineWeight = value;
    } else if ([name isEqualToString:@"scanline-gap"] || [name isEqualToString:@"scanlineGap"]) {
        _uniforms.scanlineGap = value;
    } else if ([name isEqualToString:@"mask-brightness"] || [name isEqualToString:@"maskBrightness"]) {
        _uniforms.maskBrightness = value;
    } else if ([name isEqualToString:@"bloom-factor"] || [name isEqualToString:@"bloomFactor"]) {
        _uniforms.bloomFactor = value;
    } else if ([name isEqualToString:@"input-gamma"] || [name isEqualToString:@"inputGamma"]) {
        _uniforms.inputGamma = value;
    } else if ([name isEqualToString:@"output-gamma"] || [name isEqualToString:@"outputGamma"]) {
        _uniforms.outputGamma = value;
    }
    memcpy(_uniformBuffer.contents, &_uniforms, sizeof(CRTUniforms));
}

- (void)setUniformInt:(NSString *)name value:(int)value {
    if ([name isEqualToString:@"mask-type"] || [name isEqualToString:@"maskType"]) {
        _uniforms.maskType = value;
    }
    memcpy(_uniformBuffer.contents, &_uniforms, sizeof(CRTUniforms));
}

- (void)processFrame:(CVPixelBufferRef)pixelBuffer
         outputLayer:(CAMetalLayer *)outputLayer {
    if (!_isReady || !pixelBuffer) return;

    uint64_t startTime = mach_absolute_time();

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    // Debug: log sizes once
    static BOOL sizesLogged = NO;
    if (!sizesLogged) {
        sizesLogged = YES;
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        size_t bytesPerRowPlane0 = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        size_t planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
        Boolean isPlanar = CVPixelBufferIsPlanar(pixelBuffer);

        NSLog(@"[CRT] CVPixelBuffer: %zux%zu, format=0x%08X (%c%c%c%c)",
              width, height, pixelFormat,
              (char)(pixelFormat >> 24), (char)(pixelFormat >> 16),
              (char)(pixelFormat >> 8), (char)pixelFormat);
        NSLog(@"[CRT] bytesPerRow=%zu, plane0BytesPerRow=%zu, planeCount=%zu, isPlanar=%d",
              bytesPerRow, bytesPerRowPlane0, planeCount, isPlanar);
        NSLog(@"[CRT] Output drawable: %.0fx%.0f",
              outputLayer.drawableSize.width, outputLayer.drawableSize.height);

        // Check if format matches what we expect
        if (pixelFormat != kCVPixelFormatType_32BGRA) {
            NSLog(@"[CRT] WARNING: Pixel format is NOT BGRA! Expected 0x%08X, got 0x%08X",
                  kCVPixelFormatType_32BGRA, pixelFormat);
        }
    }

    // Lock the pixel buffer to access raw pixel data
    CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (lockResult != kCVReturnSuccess) {
        NSLog(@"[CRT] Failed to lock pixel buffer: %d", lockResult);
        return;
    }

    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    if (!baseAddress) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        NSLog(@"[CRT] Failed to get base address");
        return;
    }

    // Debug: print first few pixels to check actual color values
    static BOOL pixelsLogged = NO;
    if (!pixelsLogged) {
        pixelsLogged = YES;
        uint8_t *pixels = (uint8_t *)baseAddress;
        NSLog(@"[CRT] First 5 pixels (BGRA format):");
        for (int i = 0; i < 5; i++) {
            int offset = i * 4;
            NSLog(@"[CRT]   Pixel %d: B=%d G=%d R=%d A=%d",
                  i, pixels[offset], pixels[offset+1], pixels[offset+2], pixels[offset+3]);
        }
        // Also check a pixel in the middle of the screen
        int midOffset = (height / 2) * bytesPerRow + (width / 2) * 4;
        NSLog(@"[CRT] Middle pixel: B=%d G=%d R=%d A=%d",
              pixels[midOffset], pixels[midOffset+1], pixels[midOffset+2], pixels[midOffset+3]);
    }

    // Create a managed texture and copy pixel data manually
    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:width
                                    height:height
                                 mipmapped:NO];
    textureDesc.usage = MTLTextureUsageShaderRead;
    textureDesc.storageMode = MTLStorageModeShared;

    id<MTLTexture> inputTexture = [_device newTextureWithDescriptor:textureDesc];
    if (!inputTexture) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        NSLog(@"[CRT] Failed to create input texture");
        return;
    }

    // Copy pixel data row by row to handle stride
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [inputTexture replaceRegion:region
                    mipmapLevel:0
                      withBytes:baseAddress
                    bytesPerRow:bytesPerRow];

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    // Debug: log texture info once
    static BOOL textureSizeLogged = NO;
    if (!textureSizeLogged) {
        textureSizeLogged = YES;
        NSLog(@"[CRT] Manual texture created: %lux%lu, bytesPerRow: %zu",
              (unsigned long)inputTexture.width,
              (unsigned long)inputTexture.height,
              bytesPerRow);
    }

    // Get output drawable
    id<CAMetalDrawable> drawable = [outputLayer nextDrawable];
    if (!drawable) {
        return;
    }

    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"CRT Filter";

    // Create compute encoder
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setLabel:@"CRT Compute"];

    [computeEncoder setComputePipelineState:_computePipeline];
    [computeEncoder setTexture:inputTexture atIndex:0];
    [computeEncoder setTexture:drawable.texture atIndex:1];
    [computeEncoder setBuffer:_uniformBuffer offset:0 atIndex:0];

    // Calculate thread groups
    NSUInteger threadWidth = _computePipeline.threadExecutionWidth;
    NSUInteger threadHeight = _computePipeline.maxTotalThreadsPerThreadgroup / threadWidth;

    MTLSize threadGroupSize = MTLSizeMake(threadWidth, threadHeight, 1);
    MTLSize threadGroups = MTLSizeMake(
        (drawable.texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
        (drawable.texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
        1);

    [computeEncoder dispatchThreadgroups:threadGroups
                   threadsPerThreadgroup:threadGroupSize];
    [computeEncoder endEncoding];

    // Present and commit
    [commandBuffer presentDrawable:drawable];

    // Track latency
    __weak typeof(self) weakSelf = self;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        uint64_t endTime = mach_absolute_time();
        uint64_t elapsed = endTime - startTime;

        // Convert to milliseconds
        strongSelf->_latencyMs = (float)(elapsed * strongSelf->_timebaseInfo.numer) /
                                 (float)(strongSelf->_timebaseInfo.denom * 1000000);
    }];

    [commandBuffer commit];

    // Update FPS
    _frameCount++;
    uint64_t now = mach_absolute_time();
    uint64_t elapsed = now - _lastFPSTime;
    double elapsedSec = (double)(elapsed * _timebaseInfo.numer) /
                        (double)(_timebaseInfo.denom * 1000000000);

    if (elapsedSec >= 1.0) {
        _fps = (float)_frameCount / elapsedSec;
        _frameCount = 0;
        _lastFPSTime = now;
    }
}

- (float)currentFPS {
    return _fps;
}

- (float)currentLatencyMs {
    return _latencyMs;
}

@end
