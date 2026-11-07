#import "MCMusSceneDelegate.h"

#if TARGET_OS_IOS
#import "MCMusAppDelegate-iOS.h"
#import "MainViewController-iOS.h"

@implementation MCMusSceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    // Shown in the iPad app switcher, as the SwiftUI WindowGroup title was.
    windowScene.title = @"MC Mus";
    MCMusAppDelegate *appDelegate = MCMusAppDelegate.shared;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.rootViewController = [[MainViewController alloc] initWithStore:appDelegate.store player:appDelegate.player];
    [window makeKeyAndVisible];
    self.window = window;
}

@end
#endif
