#import "UIView+FillingSubview.h"

#if TARGET_OS_IOS
@implementation UIView (FillingSubview)

- (void)addFillingSubview:(UIView *)view
{
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:self.topAnchor],
        [view.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [view.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
}

@end
#endif
