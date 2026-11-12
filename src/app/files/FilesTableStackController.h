#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "Folder.h"
#import "Player.h"

NS_ASSUME_NONNULL_BEGIN

@interface FilesTableStackController : UINavigationController

- (instancetype)initWithPlayer:(Player *)player NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithRootViewController:
    (UIViewController *)rootViewController NS_UNAVAILABLE;
- (instancetype)initWithNavigationBarClass:(nullable Class)navigationBarClass
                              toolbarClass:(nullable Class)toolbarClass
    NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil
    NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setRootFolder:(Folder *)folder;

@end

NS_ASSUME_NONNULL_END
#endif
