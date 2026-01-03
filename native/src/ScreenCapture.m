#import "ScreenCapture.h"
#import <CoreVideo/CoreVideo.h>

@implementation CRTScreenCapture {
    SCStream *_stream;
    SCContentFilter *_filter;
    SCStreamConfiguration *_config;
    dispatch_queue_t _captureQueue;
    BOOL _isCapturing;
}

- (instancetype)initWithDisplayID:(CGDirectDisplayID)displayID {
    self = [super init];
    if (self) {
        _displayID = displayID;
        _captureQueue = dispatch_queue_create("com.crt-filter.capture",
                                               DISPATCH_QUEUE_SERIAL);
        _isCapturing = NO;
    }
    return self;
}

- (BOOL)isCapturing {
    return _isCapturing;
}

- (void)startCaptureWithCompletion:(void (^)(NSError * _Nullable error))completion {
    if (_isCapturing) {
        if (completion) completion(nil);
        return;
    }

    NSLog(@"[CRT] Calling getShareableContent...");

    [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                               onScreenWindowsOnly:YES
                                                 completionHandler:^(SCShareableContent * _Nullable content,
                                                                     NSError * _Nullable error) {
        NSLog(@"[CRT] getShareableContent callback received (error: %@)", error);

        if (error) {
            NSLog(@"[CRT] Failed to get shareable content: %@", error);
            if (completion) completion(error);
            return;
        }

        // Find target display
        SCDisplay *targetDisplay = nil;
        for (SCDisplay *display in content.displays) {
            if (display.displayID == self->_displayID) {
                targetDisplay = display;
                break;
            }
        }

        if (!targetDisplay && content.displays.count > 0) {
            targetDisplay = content.displays.firstObject;
            NSLog(@"[CRT] Display ID %u not found, using first display", self->_displayID);
        }

        if (!targetDisplay) {
            NSError *err = [NSError errorWithDomain:@"CRTScreenCapture"
                                               code:1
                                           userInfo:@{NSLocalizedDescriptionKey: @"No display found"}];
            if (completion) completion(err);
            return;
        }

        // Find and exclude our overlay window
        NSMutableArray<SCWindow *> *windowsToExclude = [NSMutableArray array];
        if (self->_excludeWindowID != 0) {
            for (SCWindow *window in content.windows) {
                if (window.windowID == self->_excludeWindowID) {
                    [windowsToExclude addObject:window];
                    NSLog(@"[CRT] Excluding window ID %u from capture", self->_excludeWindowID);
                    break;
                }
            }
        }

        // Create filter - capture the whole display excluding our overlay
        self->_filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay
                                            excludingWindows:windowsToExclude];

        NSLog(@"[CRT] Found target display ID: %u, size: %zux%zu",
              targetDisplay.displayID,
              (size_t)targetDisplay.width,
              (size_t)targetDisplay.height);

        // Configure stream for low latency
        self->_config = [[SCStreamConfiguration alloc] init];

        CGFloat scale = 2.0; // Retina
        self->_config.width = targetDisplay.width * scale;
        self->_config.height = targetDisplay.height * scale;
        self->_config.minimumFrameInterval = CMTimeMake(1, 60); // 60fps
        self->_config.queueDepth = 2; // Low latency - minimal buffering
        self->_config.pixelFormat = kCVPixelFormatType_32BGRA;
        self->_config.showsCursor = YES;
        self->_config.capturesAudio = NO;

        // Create stream
        self->_stream = [[SCStream alloc] initWithFilter:self->_filter
                                           configuration:self->_config
                                                delegate:self];

        NSError *addError = nil;
        BOOL added = [self->_stream addStreamOutput:self
                                               type:SCStreamOutputTypeScreen
                                 sampleHandlerQueue:self->_captureQueue
                                              error:&addError];
        if (!added) {
            NSLog(@"[CRT] Failed to add stream output: %@", addError);
            if (completion) completion(addError);
            return;
        }

        // Start capture
        [self->_stream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
            if (startError) {
                NSLog(@"[CRT] Failed to start capture: %@", startError);
            } else {
                self->_isCapturing = YES;
                NSLog(@"[CRT] Screen capture started for display %u (%zux%zu)",
                      self->_displayID,
                      (size_t)self->_config.width,
                      (size_t)self->_config.height);
            }
            if (completion) completion(startError);
        }];
    }];
}

- (void)stopCapture {
    if (!_isCapturing) return;

    [_stream stopCaptureWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[CRT] Failed to stop capture: %@", error);
        } else {
            NSLog(@"[CRT] Screen capture stopped");
        }
    }];

    _isCapturing = NO;
    _stream = nil;
    _filter = nil;
}

#pragma mark - SCStreamOutput

- (void)stream:(SCStream *)stream
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeScreen) return;

    // Check frame status
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (!attachmentsArray || CFArrayGetCount(attachmentsArray) == 0) return;

    CFDictionaryRef attachments = CFArrayGetValueAtIndex(attachmentsArray, 0);

    // Get frame status (use SInt64 for NSInteger on 64-bit)
    CFNumberRef statusRef = CFDictionaryGetValue(attachments, SCStreamFrameInfoStatus);
    if (!statusRef) return;

    NSInteger statusValue = 0;
    CFNumberGetValue(statusRef, kCFNumberSInt64Type, &statusValue);
    SCFrameStatus status = (SCFrameStatus)statusValue;

    // Only process Complete and Idle frames
    if (status != SCFrameStatusComplete && status != SCFrameStatusIdle) {
        return;
    }

    // Get pixel buffer
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;

    // Get content rect
    CGRect contentRect = CGRectZero;
    CFDictionaryRef rectDict = CFDictionaryGetValue(attachments, SCStreamFrameInfoContentRect);
    if (rectDict) {
        CGRectMakeWithDictionaryRepresentation(rectDict, &contentRect);
    }

    // Get scale factor
    CGFloat scaleFactor = 1.0;
    CFNumberRef scaleRef = CFDictionaryGetValue(attachments, SCStreamFrameInfoScaleFactor);
    if (scaleRef) {
        CFNumberGetValue(scaleRef, kCFNumberCGFloatType, &scaleFactor);
    }

    // Call frame handler with CVPixelBuffer
    if (self.frameHandler) {
        // Debug: log contentRect once
        static BOOL contentRectLogged = NO;
        if (!contentRectLogged) {
            contentRectLogged = YES;
            NSLog(@"[CRT] ContentRect: (%.0f,%.0f) %.0fx%.0f, scaleFactor: %.1f, pixelBuffer: %zux%zu",
                  contentRect.origin.x, contentRect.origin.y,
                  contentRect.size.width, contentRect.size.height,
                  scaleFactor,
                  CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
        }

        // Retain the pixel buffer for the duration of the handler call
        CVPixelBufferRetain(pixelBuffer);
        self.frameHandler(pixelBuffer, contentRect, scaleFactor);
        CVPixelBufferRelease(pixelBuffer);
    }
}

#pragma mark - SCStreamDelegate

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    NSLog(@"[CRT] Stream stopped with error: %@", error);
    _isCapturing = NO;
}

@end
