#import "PanelView-iOS.h"

#if TARGET_OS_IOS
#import "HairlineView.h"
#import "UIView+FillingSubview.h"

static UIView *makeTitleBar(NSString *title, UIView *_Nullable accessory) {
    UIView *titleBar = [[UIView alloc] init];
    // The folder table's navigation bar uses the same color and rows
    // scroll underneath it, so this must be solid rather than a material.
    titleBar.backgroundColor = UIColor.secondarySystemBackgroundColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    // The label's height sets the title bar's, so the content has to be
    // what stretches or shrinks to fill the panel.
    [titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:titleLabel];
    // The background runs under the status bar and the notch while the
    // title and accessory stay clear of them.
    UILayoutGuide *safeArea = titleBar.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:16],
        [titleLabel.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-16],
    ]];

    if (accessory) {
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [titleBar addSubview:accessory];
        [NSLayoutConstraint activateConstraints:@[
            [accessory.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-8],
            [accessory.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        ]];
    }
    return titleBar;
}

@implementation PanelView {
    UIView *_titleBar;
    HairlineView *_titleSeparator;
    UIView *_contentContainer;
    UIView *_Nullable _contentView;
}

- (instancetype)initWithTitle:(NSString *)title accessory:(nullable UIView *)accessory {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _showsTitle = YES;
        _titleBar = makeTitleBar(title, accessory);
        _titleSeparator = [[HairlineView alloc] init];
        _contentContainer = [[UIView alloc] init];
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleBar, _titleSeparator, _contentContainer]];
        stack.axis = UILayoutConstraintAxisVertical;
        [self addFillingSubview:stack];
    }
    return self;
}

- (void)setShowsTitle:(BOOL)showsTitle {
    _showsTitle = showsTitle;
    _titleBar.hidden = !showsTitle;
    _titleSeparator.hidden = !showsTitle;
}

- (void)setContent:(UIView *)view {
    if (view == _contentView) {
        return;
    }
    [_contentView removeFromSuperview];
    _contentView = view;
    [_contentContainer addFillingSubview:view];
}

@end
#endif
