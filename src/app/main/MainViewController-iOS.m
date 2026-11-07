#import "MainViewController-iOS.h"

#if TARGET_OS_IOS
#import "FilesPanelViewController-iOS.h"
#import "HairlineView.h"
#import "PanelArrangement.h"
#import "QueuePanelViewController-iOS.h"
#import "UIView+FillingSubview.h"

@implementation MainViewController {
    FilesPanelViewController *_filesPanel;
    QueuePanelViewController *_queuePanel;
    UIStackView *_stack;
    HairlineView *_separator;
    BOOL _isArranged;
    PanelArrangement _arrangement;
    NSLayoutConstraint *_equalWidths;
    NSLayoutConstraint *_equalHeights;
}

- (instancetype)initWithStore:(MusicLibraryStore *)store player:(Player *)player {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _filesPanel = [[FilesPanelViewController alloc] initWithStore:store player:player];
        _queuePanel = [[QueuePanelViewController alloc] initWithPlayer:player];
        _stack = [[UIStackView alloc] init];
        _separator = [[HairlineView alloc] init];
    }
    return self;
}

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.systemBackgroundColor;
    self.view = view;
    [self addChildViewController:_filesPanel];
    [self addChildViewController:_queuePanel];
    for (UIView *subview in @[_filesPanel.view, _separator, _queuePanel.view]) {
        [_stack addArrangedSubview:subview];
    }
    [view addFillingSubview:_stack];
    [_filesPanel didMoveToParentViewController:self];
    [_queuePanel didMoveToParentViewController:self];
    _equalWidths = [_filesPanel.view.widthAnchor constraintEqualToAnchor:_queuePanel.view.widthAnchor];
    _equalHeights = [_filesPanel.view.heightAnchor constraintEqualToAnchor:_queuePanel.view.heightAnchor];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self arrange:PanelArrangementFitting(self.view.bounds.size)];
    [self equalizeUsableAreas];
}

- (void)arrange:(PanelArrangement)newArrangement {
    if (_isArranged && newArrangement == _arrangement) {
        return;
    }
    _isArranged = YES;
    _arrangement = newArrangement;
    [NSLayoutConstraint deactivateConstraints:@[_equalWidths, _equalHeights]];
    switch (newArrangement) {
        case PanelArrangementSideBySide:
            _stack.axis = UILayoutConstraintAxisHorizontal;
            _separator.axis = UILayoutConstraintAxisVertical;
            _equalWidths.active = YES;
            break;
        case PanelArrangementStacked:
            _stack.axis = UILayoutConstraintAxisVertical;
            _separator.axis = UILayoutConstraintAxisHorizontal;
            _equalHeights.active = YES;
            break;
    }
}

// The panels run under the safe area insets, so the files panel gets
// the difference between the insets on its side and the queue panel's
// to leave both the same room inside the safe area.
- (void)equalizeUsableAreas {
    UIEdgeInsets insets = self.view.safeAreaInsets;
    _equalWidths.constant = insets.left - insets.right;
    _equalHeights.constant = insets.top - insets.bottom;
}

@end
#endif
