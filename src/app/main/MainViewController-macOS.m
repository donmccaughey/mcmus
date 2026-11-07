#import "MainViewController-macOS.h"

#if TARGET_OS_OSX
#import "FilesPanelViewController-macOS.h"
#import "QueuePanelViewController-macOS.h"

@implementation MainViewController {
    MusicLibraryStore *_store;
    Player *_player;
}

- (instancetype)initWithStore:(MusicLibraryStore *)store player:(Player *)player {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _player = player;
    }
    return self;
}

- (void)loadView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 900, 600)];
    self.view = view;
    FilesPanelViewController *filesPanel = [[FilesPanelViewController alloc] initWithStore:_store];
    [self addChildViewController:filesPanel];
    NSBox *separator = [[NSBox alloc] init];
    separator.boxType = NSBoxSeparator;
    QueuePanelViewController *queuePanel = [[QueuePanelViewController alloc] initWithPlayer:_player];
    [self addChildViewController:queuePanel];
    for (NSView *subview in @[filesPanel.view, separator, queuePanel.view]) {
        subview.translatesAutoresizingMaskIntoConstraints = NO;
        [view addSubview:subview];
    }
    [NSLayoutConstraint activateConstraints:@[
        [filesPanel.view.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [filesPanel.view.topAnchor constraintEqualToAnchor:view.topAnchor],
        [filesPanel.view.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [separator.leadingAnchor constraintEqualToAnchor:filesPanel.view.trailingAnchor],
        [separator.widthAnchor constraintEqualToConstant:1],
        [separator.topAnchor constraintEqualToAnchor:view.topAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [queuePanel.view.leadingAnchor constraintEqualToAnchor:separator.trailingAnchor],
        [queuePanel.view.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [queuePanel.view.topAnchor constraintEqualToAnchor:view.topAnchor],
        [queuePanel.view.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [queuePanel.view.widthAnchor constraintEqualToAnchor:filesPanel.view.widthAnchor],
    ]];
    [self constrainMinimumSize];
}

// The window takes its minimum size from its content view's constraints
// and ignores contentMinSize once it has a content view controller.
- (void)constrainMinimumSize {
    [NSLayoutConstraint activateConstraints:@[
        [self.view.widthAnchor constraintGreaterThanOrEqualToConstant:640],
        [self.view.heightAnchor constraintGreaterThanOrEqualToConstant:480],
    ]];
}

@end
#endif
