#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PanelView : UIView

@property (nonatomic) BOOL showsTitle;

- (instancetype)initWithTitle:(NSString *)title accessory:(nullable UIView *)accessory NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setContent:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
#endif
