#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIButton (Bordered)

+ (UIButton *)borderedWithTitle:(NSString *)title;
+ (UIButton *)borderedWithTitle:(NSString *)title
                  primaryAction:(nullable UIAction *)primaryAction;

@end

NS_ASSUME_NONNULL_END
#endif
