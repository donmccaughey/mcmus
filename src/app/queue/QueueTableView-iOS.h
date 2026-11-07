#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "QueuedTrack.h"

NS_ASSUME_NONNULL_BEGIN

@interface QueueTableView : UIView

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setQueuedTracks:(NSArray<QueuedTrack *> *)queuedTracks;

@end

NS_ASSUME_NONNULL_END
#endif
