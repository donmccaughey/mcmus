#import "AppDelegate-iOS.h"

#if TARGET_OS_IOS
#include "AudioReal.h"
#include "DemoMode.h"
#include "FileSystemReal.h"
#include "PreferencesReal.h"


@implementation AppDelegate
{
    id<Audio> _audio;
    id<FileSystem> _fileSystem;
    id<Preferences> _preferences;
}

+ (AppDelegate *)shared {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
}

- (instancetype)init;
{
    self = [super init];
    if ( ! self) return nil;
    
    _audio = [AudioReal new];
    _fileSystem = [FileSystemReal new];
    if (isDemoMode()) {
        _audio = demoAudioWrapping(_audio);
        _fileSystem = demoFileSystemWrapping(_fileSystem);
    }
    _preferences = [PreferencesReal new];
    
    _store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                               preferences:_preferences];
    _player = [[Player alloc] initWithAudio:_audio];
    
    return self;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    [_store loadInBackground];
    return YES;
}


@end
#endif
