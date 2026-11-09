#import "AppDelegate-macOS.h"

#if TARGET_OS_OSX
#import "AudioReal.h"
#import "MainMenu.h"
#import "MainWindowController.h"
#import "MusicLibraryStore.h"
#import "Player.h"
#import "SettingsWindowController.h"

@implementation AppDelegate
{
    id<Audio> _audio;
    MusicLibraryStore *_store;
    Player *_player;
    MainWindowController *_Nullable _mainWindowController;
    SettingsWindowController *_Nullable _settingsWindowController;
}

- (instancetype)init;
{
    self = [super init];
    if ( ! self) return nil;
    
    _audio = [AudioReal new];
    _store = [[MusicLibraryStore alloc] init];
    _player = [[Player alloc] initWithAudio:_audio];
    
    return self;
}

- (MainWindowController *)mainWindowController {
    if (!_mainWindowController) {
        _mainWindowController = [[MainWindowController alloc] initWithStore:_store player:_player];
    }
    return _mainWindowController;
}

- (SettingsWindowController *)settingsWindowController {
    if (!_settingsWindowController) {
        _settingsWindowController = [[SettingsWindowController alloc] initWithStore:_store];
    }
    return _settingsWindowController;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    NSWindow.allowsAutomaticWindowTabbing = NO;
    NSApp.mainMenu = makeMainMenu(self, @selector(showSettings:));
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [_store loadInBackgroundIsDemo:[NSProcessInfo.processInfo.arguments containsObject:@"--demo"]];
    [self.mainWindowController showWindow:nil];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)showSettings:(nullable id)sender {
    [self.settingsWindowController showWindow:sender];
}

@end
#endif
