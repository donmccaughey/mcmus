#import "EmptyStateView-macOS.h"

#if TARGET_OS_OSX
@implementation EmptyStateView {
    NSTextField *_descriptionLabel;
}

- (instancetype)initWithTitle:(NSString *)title systemImage:(NSString *)systemImage description:(NSString *)description {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        NSImage *image = [NSImage imageWithSystemSymbolName:systemImage accessibilityDescription:nil];
        NSImageView *imageView = [NSImageView imageViewWithImage:image];
        imageView.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:36 weight:NSFontWeightRegular];
        imageView.contentTintColor = NSColor.secondaryLabelColor;

        NSTextField *titleLabel = [NSTextField labelWithString:title];
        CGFloat titleSize = [NSFont preferredFontForTextStyle:NSFontTextStyleLargeTitle options:@{}].pointSize;
        titleLabel.font = [NSFont systemFontOfSize:titleSize weight:NSFontWeightBold];
        titleLabel.textColor = NSColor.secondaryLabelColor;

        _descriptionLabel = [NSTextField labelWithString:description];
        _descriptionLabel.font = [NSFont preferredFontForTextStyle:NSFontTextStyleBody options:@{}];
        _descriptionLabel.textColor = NSColor.secondaryLabelColor;

        NSStackView *stack = [NSStackView stackViewWithViews:@[imageView, titleLabel, _descriptionLabel]];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.alignment = NSLayoutAttributeCenterX;
        stack.spacing = 12;
        [stack setCustomSpacing:24 afterView:imageView];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:16],
            [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],
        ]];
    }
    return self;
}

- (NSString *)descriptionText {
    return _descriptionLabel.stringValue;
}

- (void)setDescriptionText:(NSString *)descriptionText {
    _descriptionLabel.stringValue = descriptionText;
}

@end
#endif
