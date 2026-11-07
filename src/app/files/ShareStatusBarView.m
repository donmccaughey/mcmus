#import "ShareStatusBarView.h"

#if TARGET_OS_OSX
static const CGFloat leadingPadding = 16;
// Lines the switch up with the accessory button in the panel title bar.
static const CGFloat trailingPadding = 8;
static const CGFloat verticalPadding = 8;
static const CGFloat spacing = 8;

@implementation ShareStatusBarView {
    NSSwitch *_shareSwitch;
    NSTextField *_statusLabel;
}

- (instancetype)init {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _shareSwitch = [[NSSwitch alloc] init];
        _statusLabel = [NSTextField labelWithString:@""];
        NSTextField *titleLabel = [NSTextField labelWithString:@"File Sharing"];
        titleLabel.font = [NSFont preferredFontForTextStyle:NSFontTextStyleBody options:@{}];
        [titleLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        [titleLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                             forOrientation:NSLayoutConstraintOrientationHorizontal];
        _statusLabel.font = [NSFont preferredFontForTextStyle:NSFontTextStyleSubheadline options:@{}];
        _statusLabel.textColor = NSColor.secondaryLabelColor;
        _statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _statusLabel.maximumNumberOfLines = 1;
        [_statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                               forOrientation:NSLayoutConstraintOrientationHorizontal];
        _shareSwitch.target = self;
        _shareSwitch.action = @selector(update);
        [_shareSwitch setAccessibilityLabel:@"File Sharing"];

        for (NSView *subview in @[titleLabel, _statusLabel, _shareSwitch]) {
            subview.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:subview];
        }
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:leadingPadding],
            [titleLabel.centerYAnchor constraintEqualToAnchor:_shareSwitch.centerYAnchor],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:spacing],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_shareSwitch.leadingAnchor constant:-spacing],
            [_statusLabel.firstBaselineAnchor constraintEqualToAnchor:titleLabel.firstBaselineAnchor],
            [_shareSwitch.topAnchor constraintEqualToAnchor:self.topAnchor constant:verticalPadding],
            [_shareSwitch.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-trailingPadding],
            [_shareSwitch.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-verticalPadding],
        ]];
        [self setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
        [self update];
    }
    return self;
}

- (NSString *)statusText {
    return _shareSwitch.state == NSControlStateValueOn ? @"No device connected." : @"Not sharing.";
}

- (void)update {
    _statusLabel.stringValue = self.statusText;
}

@end
#endif
