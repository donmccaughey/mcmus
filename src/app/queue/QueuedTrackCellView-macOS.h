#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "Track.h"

NS_ASSUME_NONNULL_BEGIN

@interface QueuedTrackCellView : NSTableCellView

@property (class, nonatomic, readonly)
    NSUserInterfaceItemIdentifier reuseIdentifier;
// The cell places its labels by hand in layout, so the table cannot
// measure a fitting height and takes this fixed one instead.
@property (class, nonatomic, readonly) CGFloat rowHeight;

- (instancetype)initWithFrame:(NSRect)frame NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)show:(Track *)track;

@end

NS_ASSUME_NONNULL_END
#endif
