#import "UIButton+Bordered.h"

#if TARGET_OS_IOS
@implementation UIButton (Bordered)

+ (UIButton *)borderedWithTitle:(NSString *)title {
    return [self borderedWithTitle:title primaryAction:nil];
}

+ (UIButton *)borderedWithTitle:(NSString *)title primaryAction:(nullable UIAction *)primaryAction {
    UIButtonConfiguration *configuration = [UIButtonConfiguration borderedButtonConfiguration];
    configuration.title = title;
    return [UIButton buttonWithConfiguration:configuration primaryAction:primaryAction];
}

@end
#endif
