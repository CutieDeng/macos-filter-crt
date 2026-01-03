#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface CRTOverlayWindow : NSWindow

@property (nonatomic, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, readonly) id<MTLDevice> device;

- (instancetype)initWithScreen:(NSScreen *)screen device:(id<MTLDevice>)device;
- (void)updateSize;

@end

@interface CRTMetalView : NSView

@property (nonatomic, strong) CAMetalLayer *metalLayer;

- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device;

@end
