#import "NSStackView+SeparatedRows.h"

#if TARGET_OS_OSX
static NSStackView *separatedRows(NSView *top, NSView *bottom, NSView *body) {
    NSBox *separator = [[NSBox alloc] init];
    separator.boxType = NSBoxSeparator;
    NSArray<NSView *> *rows = @[top, separator, bottom];
    NSStackView *stack = [NSStackView stackViewWithViews:rows];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 0;
    stack.distribution = NSStackViewDistributionFill;
    // Stack alignment alone leaves a row that hugs its content at its
    // narrowest width, so pin every row to the full width.
    for (NSView *row in rows) {
        [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }
    // A separator box has no fixed thickness of its own, so without this
    // the stack stretches it over the space meant for the body.
    [separator.heightAnchor constraintEqualToConstant:1].active = YES;
    [body setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];
    return stack;
}

@implementation NSStackView (SeparatedRows)

+ (NSStackView *)headerOverBody:(NSView *)header body:(NSView *)body {
    return separatedRows(header, body, body);
}

+ (NSStackView *)bodyOverFooter:(NSView *)body footer:(NSView *)footer {
    return separatedRows(body, footer, body);
}

@end
#endif
