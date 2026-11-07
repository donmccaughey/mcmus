#import "AppDelegate-iOS.h"

#if TARGET_OS_IOS
@implementation AppDelegate

+ (AppDelegate *)shared {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _store = [[MusicLibraryStore alloc] init];
        _player = [[Player alloc] init];
    }
    return self;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    [_store loadInBackgroundIsDemo:[NSProcessInfo.processInfo.arguments containsObject:@"--demo"]];
    return YES;
}

@end
#endif
