#import "OverlayWindow.h"

@implementation CRTMetalView

- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;

        _metalLayer = [CAMetalLayer layer];
        _metalLayer.device = device;
        _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _metalLayer.framebufferOnly = NO;
        _metalLayer.displaySyncEnabled = YES;
        _metalLayer.opaque = YES;
        _metalLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];

        self.layer = _metalLayer;

        NSLog(@"[CRT] Metal view created - layer size: %.0fx%.0f",
              frame.size.width, frame.size.height);
    }
    return self;
}

- (CALayer *)makeBackingLayer {
    return _metalLayer ?: [CAMetalLayer layer];
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    _metalLayer.contentsScale = self.window.backingScaleFactor;
}

@end

@implementation CRTOverlayWindow {
    CRTMetalView *_metalView;
}

- (instancetype)initWithScreen:(NSScreen *)screen device:(id<MTLDevice>)device {
    NSRect frame = screen.frame;

    self = [super initWithContentRect:frame
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:NO
                               screen:screen];
    if (self) {
        _device = device;

        // Transparent background
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setHasShadow:NO];

        // Float above all windows - use a reasonable high level
        // CGShieldingWindowLevel is very high and might be restricted
        // NSFloatingWindowLevel = 3, NSPopUpMenuWindowLevel = 101
        // Use a level above most windows but not at the extreme
        [self setLevel:NSFloatingWindowLevel + 100];

        // Ignore all mouse events - pass through to windows below
        [self setIgnoresMouseEvents:YES];

        // Visible on all spaces including fullscreen
        [self setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorFullScreenAuxiliary |
            NSWindowCollectionBehaviorStationary |
            NSWindowCollectionBehaviorIgnoresCycle];

        // Create Metal view
        _metalView = [[CRTMetalView alloc] initWithFrame:frame device:device];
        [self setContentView:_metalView];
        _metalLayer = _metalView.metalLayer;

        // Update layer size
        [self updateSize];

        // Register for screen change notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenDidChange:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)screenDidChange:(NSNotification *)notification {
    [self updateSize];
}

- (void)updateSize {
    NSScreen *screen = self.screen ?: [NSScreen mainScreen];
    NSRect frame = screen.frame;

    [self setFrame:frame display:YES];

    CGFloat scale = screen.backingScaleFactor;
    _metalLayer.contentsScale = scale;
    _metalLayer.drawableSize = CGSizeMake(frame.size.width * scale,
                                           frame.size.height * scale);
}

// Never become key window - stay passive
- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

// Exclude from screen capture to avoid recursion
- (NSWindowSharingType)sharingType {
    return NSWindowSharingNone;
}

@end
