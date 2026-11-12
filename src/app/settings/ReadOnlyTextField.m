#import "ReadOnlyTextField.h"

#if TARGET_OS_OSX
@implementation ReadOnlyTextField

- (instancetype)init
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.editable = NO;
        self.selectable = YES;
        self.bezeled = YES;
        self.maximumNumberOfLines = 1;
        self.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self
            setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                     forOrientation:
                                         NSLayoutConstraintOrientationHorizontal];
        [self
            setContentHuggingPriority:NSLayoutPriorityDefaultLow
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
        // While text is selected the field editor lays out the full,
        // untruncated string, which would spill over neighboring controls.
        self.clipsToBounds = YES;
    }
    return self;
}

// refusesFirstResponder would also stop a mouse click from selecting the
// text, so only the key view loop (Tab order and initial focus) is opted out.
- (BOOL)canBecomeKeyView
{
    return NO;
}

- (void)setText:(NSString *)text
{
    if ([self.stringValue isEqualToString:text]) {
        return;
    }
    // Otherwise a selection made before choosing a new path comes back as
    // the whole new value selected.
    [self abortEditing];
    self.stringValue = text;
}

@end
#endif
