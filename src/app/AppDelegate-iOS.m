#import "AppDelegate-iOS.h"

#if TARGET_OS_IOS
#include "AudioReal.h"


@implementation AppDelegate
{
    id<Audio> _audio;
}

+ (AppDelegate *)shared {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
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

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    [_store loadInBackgroundIsDemo:[NSProcessInfo.processInfo.arguments containsObject:@"--demo"]];
    return YES;
}


@end
#endif
