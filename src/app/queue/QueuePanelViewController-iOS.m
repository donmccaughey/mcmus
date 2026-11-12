#import "QueuePanelViewController-iOS.h"

#if TARGET_OS_IOS
#import "EmptyStateView-iOS.h"
#import "HairlineView.h"
#import "PanelView-iOS.h"
#import "PlayerPanelView-iOS.h"
#import "QueueTableView-iOS.h"
#import "UIButton+Bordered.h"
#import "UIView+FillingSubview.h"

@implementation QueuePanelViewController {
    Player *_player;
    UIButton *_clearButton;
    EmptyStateView *_emptyQueueView;
    QueueTableView *_queueTableView;
}

- (instancetype)initWithPlayer:(Player *)player
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _player = player;
        _clearButton = [UIButton
            borderedWithTitle:@"Clear"
                primaryAction:[UIAction actionWithHandler:^(
                                  UIAction *action) { [player clear]; }]];
        _emptyQueueView =
            [[EmptyStateView alloc] initWithTitle:@"No tracks"
                                      systemImage:@"list.bullet"
                                      description:@"The queue is empty."];
        _queueTableView = [[QueueTableView alloc] init];
    }
    return self;
}

- (void)loadView
{
    PanelView *panelView = [[PanelView alloc] initWithTitle:@"Queue"
                                                  accessory:_clearButton];
    [panelView setContent:[self makeQueueView]];
    self.view = panelView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(update)
                                               name:Queue.didChangeNotification
                                             object:_player.queue];
    [self update];
}

- (void)update
{
    NSArray<QueuedTrack *> *queuedTracks = _player.queue.queuedTracks;
    _clearButton.enabled = queuedTracks.count > 0;
    _emptyQueueView.hidden = queuedTracks.count > 0;
    _queueTableView.hidden = queuedTracks.count == 0;
    [_queueTableView setQueuedTracks:queuedTracks];
}

- (UIView *)makeQueueView
{
    UIView *queueBody = [[UIView alloc] init];
    [queueBody addFillingSubview:_emptyQueueView];
    [queueBody addFillingSubview:_queueTableView];
    PlayerPanelView *playerPanel =
        [[PlayerPanelView alloc] initWithPlayer:_player];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        playerPanel, [[HairlineView alloc] init], queueBody
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    return stack;
}

@end
#endif
