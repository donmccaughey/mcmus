#import "AppDelegate-iOS.h"

#if TARGET_OS_IOS
#include "AudioReal.h"
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
    _preferences = [PreferencesReal new];
    
    _store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                               preferences:_preferences];
    _player = [[Player alloc] initWithAudio:_audio];
    
    return self;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    [_store loadInBackgroundIsDemo:[NSProcessInfo.processInfo.arguments containsObject:@"--demo"]];
    return YES;
}


@end
#endif
