#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <IOSurface/IOSurface.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

// CRT effect uniforms structure - must match Metal shader
typedef struct {
    float scanlineWeight;
    float scanlineGap;
    float maskBrightness;
    int   maskType;
    float bloomFactor;
    float inputGamma;
    float outputGamma;
    float _padding; // Align to 16 bytes
} CRTUniforms;

@interface CRTMetalRenderer : NSObject

@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;
@property (nonatomic, readonly) BOOL isReady;
@property (nonatomic, readonly) float currentFPS;
@property (nonatomic, readonly) float currentLatencyMs;

- (instancetype)initWithDevice:(id<MTLDevice>)device;

// Shader management
- (BOOL)loadShaderFromSource:(NSString *)source error:(NSError **)error;
- (BOOL)loadShaderFromFile:(NSString *)path error:(NSError **)error;

// Uniform updates
- (void)updateUniforms:(CRTUniforms)uniforms;
- (void)setUniformFloat:(NSString *)name value:(float)value;
- (void)setUniformInt:(NSString *)name value:(int)value;

// Rendering - uses CVPixelBuffer for proper texture creation
- (void)processFrame:(CVPixelBufferRef)pixelBuffer
         outputLayer:(CAMetalLayer *)outputLayer;

@end

NS_ASSUME_NONNULL_END
