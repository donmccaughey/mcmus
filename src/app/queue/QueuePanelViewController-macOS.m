#import "QueuePanelViewController-macOS.h"

#if TARGET_OS_OSX
#import "DropTargetView.h"
#import "EmptyStateView-macOS.h"
#import "NSStackView+SeparatedRows.h"
#import "NSView+FillingSubview.h"
#import "PanelView-macOS.h"
#import "PlayerPanelView-macOS.h"
#import "QueueTableView-macOS.h"

@implementation QueuePanelViewController {
    Player *_player;
    NSButton *_clearButton;
    EmptyStateView *_emptyQueueView;
    QueueTableView *_queueTableView;
}

- (instancetype)initWithPlayer:(Player *)player
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _player = player;
        _clearButton = [NSButton buttonWithTitle:@"Clear" target:nil
                                          action:nil];
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
    _clearButton.bezelStyle = NSBezelStylePush;
    _clearButton.controlSize = NSControlSizeRegular;
    _clearButton.target = self;
    _clearButton.action = @selector(clear);
    DropTargetView *dropTargetView = [[DropTargetView alloc] init];
    Player *player = _player;
    dropTargetView.onDrop = ^(NSArray<id<FolderChild>> *children) {
        [player.queue addChildren:children];
    };
    NSView *queueBody = [[NSView alloc] init];
    [queueBody addFillingSubview:_emptyQueueView];
    [queueBody addFillingSubview:_queueTableView];
    [dropTargetView
        setContent:[NSStackView headerOverBody:[[PlayerPanelView alloc]
                                                   initWithPlayer:player]
                                          body:queueBody]];
    PanelView *panelView = [[PanelView alloc] initWithTitle:@"Queue"
                                                  accessory:_clearButton];
    [panelView setContent:dropTargetView];
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

- (void)clear
{
    [_player clear];
}

@end
#endif
