#import "HairlineView.h"

#if TARGET_OS_IOS
@implementation HairlineView

- (instancetype)initWithAxis:(UILayoutConstraintAxis)axis {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _axis = axis;
        self.backgroundColor = UIColor.separatorColor;
        // Only the thin axis has an intrinsic size, so these keep a stack
        // view from stretching the line's thickness whichever way it runs.
        UILayoutConstraintAxis layoutAxes[] = {UILayoutConstraintAxisHorizontal, UILayoutConstraintAxisVertical};
        for (size_t i = 0; i < sizeof(layoutAxes) / sizeof(layoutAxes[0]); i++) {
            [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:layoutAxes[i]];
            [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:layoutAxes[i]];
        }
        [self registerForTraitChanges:@[UITraitDisplayScale.class] withAction:@selector(invalidateIntrinsicContentSize)];
    }
    return self;
}

- (instancetype)init {
    return [self initWithAxis:UILayoutConstraintAxisHorizontal];
}

- (void)setAxis:(UILayoutConstraintAxis)axis {
    if (axis == _axis) {
        return;
    }
    _axis = axis;
    [self invalidateIntrinsicContentSize];
}

- (CGSize)intrinsicContentSize {
    CGFloat thickness = 1 / self.traitCollection.displayScale;
    if (_axis == UILayoutConstraintAxisVertical) {
        return CGSizeMake(thickness, UIViewNoIntrinsicMetric);
    }
    return CGSizeMake(UIViewNoIntrinsicMetric, thickness);
}

@end
#endif
