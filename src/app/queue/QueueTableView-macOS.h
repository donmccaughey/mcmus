#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "QueuedTrack.h"

NS_ASSUME_NONNULL_BEGIN

@interface QueueTableView : NSScrollView

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setQueuedTracks:(NSArray<QueuedTrack *> *)queuedTracks;

@end

NS_ASSUME_NONNULL_END
#endif
