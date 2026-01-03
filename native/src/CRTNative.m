#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import "OverlayWindow.h"
#import "ScreenCapture.h"
#import "MetalRenderer.h"
#import "../include/crt_native.h"

// Global state
static id<MTLDevice> g_device = nil;
static CRTOverlayWindow *g_window = nil;
static CRTScreenCapture *g_capture = nil;
static CRTMetalRenderer *g_renderer = nil;
static BOOL g_initialized = NO;
static NSString *g_currentShaderSource = nil;

// Forward declaration
static void runOnMainThreadSync(dispatch_block_t block);

#pragma mark - Initialization

bool crt_init(void) {
    if (g_initialized) return true;

    @autoreleasepool {
        // Initialize NSApplication if not already done
        if (NSApp == nil) {
            [NSApplication sharedApplication];
            // Use Regular policy to ensure windows can be displayed
            // (Accessory policy may prevent windows from being visible)
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        }

        // Get default Metal device
        g_device = MTLCreateSystemDefaultDevice();
        if (!g_device) {
            NSLog(@"[CRT] Failed to create Metal device");
            return false;
        }

        // Create renderer
        g_renderer = [[CRTMetalRenderer alloc] initWithDevice:g_device];
        if (!g_renderer) {
            NSLog(@"[CRT] Failed to create Metal renderer");
            return false;
        }

        g_initialized = YES;
        NSLog(@"[CRT] Initialized successfully");
        return true;
    }
}

void crt_shutdown(void) {
    if (!g_initialized) return;

    @autoreleasepool {
        crt_stop_capture();
        crt_hide_overlay();

        g_renderer = nil;
        g_window = nil;
        g_capture = nil;
        g_device = nil;
        g_currentShaderSource = nil;

        g_initialized = NO;
        NSLog(@"[CRT] Shutdown complete");
    }
}

#pragma mark - Screen Capture

bool crt_start_capture(uint32_t display_id) {
    if (!g_initialized) return false;

    @autoreleasepool {
        // Stop existing capture
        if (g_capture) {
            [g_capture stopCapture];
        }

        // Use main display if 0 passed
        CGDirectDisplayID displayID = display_id;
        if (displayID == 0) {
            displayID = CGMainDisplayID();
        }

        // Create and show overlay window FIRST so we can exclude it from capture
        // The window must be visible to appear in SCShareableContent
        __block CGWindowID overlayWindowID = 0;
        runOnMainThreadSync(^{
            if (!g_window) {
                NSScreen *screen = [NSScreen mainScreen];
                g_window = [[CRTOverlayWindow alloc] initWithScreen:screen
                                                            device:g_device];
            }
            // Make window visible so it shows up in SCShareableContent
            [g_window orderFront:nil];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

            overlayWindowID = (CGWindowID)[g_window windowNumber];
            NSLog(@"[CRT] Overlay window ID for exclusion: %u", overlayWindowID);
        });

        // Create capture with window exclusion
        g_capture = [[CRTScreenCapture alloc] initWithDisplayID:displayID];
        g_capture.excludeWindowID = overlayWindowID;

        // Set frame handler - use global g_window directly
        __weak CRTMetalRenderer *weakRenderer = g_renderer;

        g_capture.frameHandler = ^(CVPixelBufferRef pixelBuffer, CGRect contentRect, CGFloat scaleFactor) {
            (void)contentRect;
            (void)scaleFactor;
            CRTMetalRenderer *renderer = weakRenderer;

            // Access g_window directly since it may be created after capture starts
            if (renderer && g_window && g_window.isVisible) {
                [renderer processFrame:pixelBuffer outputLayer:g_window.metalLayer];
            }
        };

        // Start capture using semaphore with timeout
        // SCShareableContent callbacks come from a background dispatch queue
        __block BOOL success = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        NSLog(@"[CRT] Starting capture for display %u...", displayID);

        [g_capture startCaptureWithCompletion:^(NSError *error) {
            success = (error == nil);
            if (error) {
                NSLog(@"[CRT] Start capture failed: %@", error);
            } else {
                NSLog(@"[CRT] Capture started successfully");
            }
            dispatch_semaphore_signal(semaphore);
        }];

        // Wait up to 10 seconds for capture to start
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC));
        long result = dispatch_semaphore_wait(semaphore, timeout);

        if (result != 0) {
            NSLog(@"[CRT] Start capture timed out after 10 seconds");
            return false;
        }

        return success;
    }
}

void crt_stop_capture(void) {
    if (g_capture) {
        [g_capture stopCapture];
        g_capture = nil;
    }
}

#pragma mark - Shader Management

bool crt_load_shader(const char* metal_source) {
    if (!g_initialized || !metal_source) return false;

    @autoreleasepool {
        NSString *source = [NSString stringWithUTF8String:metal_source];
        NSError *error = nil;

        BOOL success = [g_renderer loadShaderFromSource:source error:&error];
        if (success) {
            g_currentShaderSource = source;
        }
        return success;
    }
}

bool crt_load_shader_from_file(const char* path) {
    if (!g_initialized || !path) return false;

    @autoreleasepool {
        NSString *filePath = [NSString stringWithUTF8String:path];
        NSError *error = nil;

        BOOL success = [g_renderer loadShaderFromFile:filePath error:&error];
        if (success) {
            g_currentShaderSource = [NSString stringWithContentsOfFile:filePath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:nil];
        }
        return success;
    }
}

bool crt_reload_shader(void) {
    if (!g_initialized || !g_currentShaderSource) return false;

    @autoreleasepool {
        NSError *error = nil;
        return [g_renderer loadShaderFromSource:g_currentShaderSource error:&error];
    }
}

#pragma mark - Uniforms

void crt_set_uniform_float(const char* name, float value) {
    if (!g_initialized || !name) return;

    @autoreleasepool {
        NSString *uniformName = [NSString stringWithUTF8String:name];
        [g_renderer setUniformFloat:uniformName value:value];
    }
}

void crt_set_uniform_int(const char* name, int value) {
    if (!g_initialized || !name) return;

    @autoreleasepool {
        NSString *uniformName = [NSString stringWithUTF8String:name];
        [g_renderer setUniformInt:uniformName value:value];
    }
}

#pragma mark - Overlay Window

// Helper to run block on main thread synchronously
static void runOnMainThreadSync(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

void crt_show_overlay(void) {
    if (!g_initialized) return;

    @autoreleasepool {
        runOnMainThreadSync(^{
            if (!g_window) {
                NSScreen *screen = [NSScreen mainScreen];
                g_window = [[CRTOverlayWindow alloc] initWithScreen:screen
                                                            device:g_device];

                // Update the capture's frame handler to use the new window
                if (g_capture) {
                    __weak CRTMetalRenderer *weakRenderer = g_renderer;
                    g_capture.frameHandler = ^(CVPixelBufferRef pixelBuffer, CGRect contentRect, CGFloat scaleFactor) {
                        (void)contentRect;
                        (void)scaleFactor;
                        CRTMetalRenderer *renderer = weakRenderer;
                        if (renderer && g_window && g_window.isVisible) {
                            [renderer processFrame:pixelBuffer outputLayer:g_window.metalLayer];
                        }
                    };
                }
            }

            [NSApp activateIgnoringOtherApps:YES];
            [g_window orderFront:nil];
            [g_window display];
            g_window.hidesOnDeactivate = NO;

            // Process run loop briefly to ensure window is displayed
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];

            NSLog(@"[CRT] Overlay: window=%.0fx%.0f@(%.0f,%.0f), screen=%.0fx%.0f@(%.0f,%.0f), drawable=%.0fx%.0f",
                  g_window.frame.size.width, g_window.frame.size.height,
                  g_window.frame.origin.x, g_window.frame.origin.y,
                  g_window.screen.frame.size.width, g_window.screen.frame.size.height,
                  g_window.screen.frame.origin.x, g_window.screen.frame.origin.y,
                  g_window.metalLayer.drawableSize.width, g_window.metalLayer.drawableSize.height);
        });
    }
}

void crt_hide_overlay(void) {
    if (!g_window) return;

    @autoreleasepool {
        runOnMainThreadSync(^{
            [g_window orderOut:nil];
            NSLog(@"[CRT] Overlay window hidden");
        });
    }
}

void crt_toggle_overlay(void) {
    if (!g_window) {
        crt_show_overlay();
    } else if (g_window.isVisible) {
        crt_hide_overlay();
    } else {
        crt_show_overlay();
    }
}

bool crt_is_overlay_visible(void) {
    return g_window && g_window.isVisible;
}

#pragma mark - Status

bool crt_is_running(void) {
    return g_initialized && g_capture && g_capture.isCapturing;
}

float crt_get_fps(void) {
    if (!g_renderer) return 0.0f;
    return g_renderer.currentFPS;
}

float crt_get_latency_ms(void) {
    if (!g_renderer) return 0.0f;
    return g_renderer.currentLatencyMs;
}

#pragma mark - Display Info

uint32_t crt_get_main_display_id(void) {
    return CGMainDisplayID();
}

void crt_get_display_size(uint32_t display_id, uint32_t* width, uint32_t* height) {
    CGDirectDisplayID displayID = display_id ? display_id : CGMainDisplayID();
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(displayID);

    if (mode) {
        if (width) *width = (uint32_t)CGDisplayModeGetWidth(mode);
        if (height) *height = (uint32_t)CGDisplayModeGetHeight(mode);
        CGDisplayModeRelease(mode);
    } else {
        if (width) *width = 0;
        if (height) *height = 0;
    }
}

#pragma mark - Debug Test Window

void crt_test_window(void) {
    @autoreleasepool {
        NSLog(@"[CRT TEST] Creating simple test window...");

        // Ensure app is initialized
        if (NSApp == nil) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSScreen *screen = [NSScreen mainScreen];
            NSRect frame = NSMakeRect(100, 100, 500, 400);  // Small window, not fullscreen

            NSWindow *testWindow = [[NSWindow alloc]
                initWithContentRect:frame
                          styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                            backing:NSBackingStoreBuffered
                              defer:NO
                             screen:screen];

            [testWindow setTitle:@"CRT Test Window"];
            [testWindow setBackgroundColor:[NSColor orangeColor]];
            [testWindow setLevel:NSFloatingWindowLevel];

            NSLog(@"[CRT TEST] Window created, making visible...");

            [NSApp activateIgnoringOtherApps:YES];
            [testWindow makeKeyAndOrderFront:nil];

            NSLog(@"[CRT TEST] Window should now be visible (frame: %.0fx%.0f at (%.0f,%.0f))",
                  testWindow.frame.size.width, testWindow.frame.size.height,
                  testWindow.frame.origin.x, testWindow.frame.origin.y);

            // Keep window alive for 5 seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [testWindow close];
                NSLog(@"[CRT TEST] Test window closed");
            });

            // Run the run loop to process events
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.5]];
        });

        // Run main run loop on this thread
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:6.0]];
    }
}
