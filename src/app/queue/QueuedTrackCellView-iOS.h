#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "Track.h"

NS_ASSUME_NONNULL_BEGIN

@interface QueuedTrackCellView : UITableViewCell

@property (class, nonatomic, readonly) NSString *reuseIdentifier;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

// The cell places its labels by hand in layoutSubviews, so the table
// cannot measure a fitting height and takes this one instead.
+ (CGFloat)rowHeightForTraitCollection:(UITraitCollection *)traitCollection;

- (void)show:(Track *)track;

@end

NS_ASSUME_NONNULL_END
#endif
