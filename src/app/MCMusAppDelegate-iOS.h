#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "MusicLibraryStore.h"
#import "Player.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCMusAppDelegate : UIResponder <UIApplicationDelegate>

@property (class, nonatomic, readonly) MCMusAppDelegate *shared;

@property (nonatomic, readonly) MusicLibraryStore *store;
@property (nonatomic, readonly) Player *player;

@end

NS_ASSUME_NONNULL_END
#endif
