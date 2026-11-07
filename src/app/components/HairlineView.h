#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HairlineView : UIView

@property (nonatomic) UILayoutConstraintAxis axis;

- (instancetype)initWithAxis:(UILayoutConstraintAxis)axis NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
