#import "MainWindowController.h"

#if TARGET_OS_OSX
#import "MainViewController-macOS.h"

@implementation MainWindowController

- (instancetype)initWithStore:(MusicLibraryStore *)store player:(Player *)player {
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 600)
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"MC Mus";
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.restorable = NO;
    // Setting the content view controller resizes the window, so it goes
    // before centering and before the autosaved frame is restored.
    window.contentViewController = [[MainViewController alloc] initWithStore:store player:player];
    [window center];
    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        // The controller resets the window's own frame autosave name when it
        // takes the window, so the name has to be set through the controller.
        self.shouldCascadeWindows = NO;
        self.windowFrameAutosaveName = @"main";
    }
    return self;
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp terminate:nil];
}

@end
#endif
