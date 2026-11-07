#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "MusicLibraryStore.h"
#import "Player.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (class, nonatomic, readonly) AppDelegate *shared;

@property (nonatomic, readonly) MusicLibraryStore *store;
@property (nonatomic, readonly) Player *player;

@end

NS_ASSUME_NONNULL_END
#endif
