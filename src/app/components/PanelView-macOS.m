#import "PanelView-macOS.h"

#if TARGET_OS_OSX
#import "NSView+FillingSubview.h"

static NSView *makeTitleBar(NSString *title, NSView *_Nullable accessory)
{
    NSVisualEffectView *titleBar = [[NSVisualEffectView alloc] init];
    titleBar.material = NSVisualEffectMaterialHeaderView;
    titleBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;

    NSTextField *titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont preferredFontForTextStyle:NSFontTextStyleHeadline
                                                options:@{}];
    titleLabel.alignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:titleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor
            constraintEqualToAnchor:titleBar.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:titleBar.topAnchor
                                             constant:16],
        [titleLabel.bottomAnchor constraintEqualToAnchor:titleBar.bottomAnchor
                                                constant:-16],
    ]];

    if (accessory) {
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [titleBar addSubview:accessory];
        [NSLayoutConstraint activateConstraints:@[
            [accessory.trailingAnchor
                constraintEqualToAnchor:titleBar.trailingAnchor
                               constant:-8],
            [accessory.centerYAnchor
                constraintEqualToAnchor:titleBar.centerYAnchor],
        ]];
    }
    return titleBar;
}

@implementation PanelView {
    NSView *_contentContainer;
    NSView *_Nullable _contentView;
}

- (instancetype)initWithTitle:(NSString *)title
                    accessory:(nullable NSView *)accessory
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _contentContainer = [[NSView alloc] init];
        NSView *titleBar = makeTitleBar(title, accessory);
        NSBox *separator = [[NSBox alloc] init];
        separator.boxType = NSBoxSeparator;
        for (NSView *subview in @[titleBar, separator, _contentContainer]) {
            subview.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:subview];
        }
        [NSLayoutConstraint activateConstraints:@[
            [titleBar.topAnchor constraintEqualToAnchor:self.topAnchor],
            [titleBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [titleBar.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor],
            [separator.topAnchor constraintEqualToAnchor:titleBar.bottomAnchor],
            [separator.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor],
            [separator.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor],
            [separator.heightAnchor constraintEqualToConstant:1],
            [_contentContainer.topAnchor
                constraintEqualToAnchor:separator.bottomAnchor],
            [_contentContainer.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor],
            [_contentContainer.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor],
            [_contentContainer.bottomAnchor
                constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)setContent:(NSView *)view
{
    if (view == _contentView) {
        return;
    }
    [_contentView removeFromSuperview];
    _contentView = view;
    [_contentContainer addFillingSubview:view];
}

@end
#endif
