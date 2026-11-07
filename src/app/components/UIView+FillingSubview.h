#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (FillingSubview)

- (void)addFillingSubview:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
#endif
