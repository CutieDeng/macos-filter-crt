#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CRTFrameHandler)(CVPixelBufferRef pixelBuffer, CGRect contentRect, CGFloat scaleFactor);

@interface CRTScreenCapture : NSObject <SCStreamDelegate, SCStreamOutput>

@property (nonatomic, readonly) BOOL isCapturing;
@property (nonatomic, copy, nullable) CRTFrameHandler frameHandler;
@property (nonatomic, readonly) CGDirectDisplayID displayID;
@property (nonatomic, assign) CGWindowID excludeWindowID;  // Window to exclude from capture

- (instancetype)initWithDisplayID:(CGDirectDisplayID)displayID;
- (void)startCaptureWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END
