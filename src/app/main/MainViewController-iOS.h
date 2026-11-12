#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "MusicLibraryStore.h"
#import "Player.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController : UIViewController

- (instancetype)initWithStore:(MusicLibraryStore *)store
                       player:(Player *)player NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil
    NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
