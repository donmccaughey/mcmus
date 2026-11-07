#import "QueueTableView-macOS.h"

#if TARGET_OS_OSX
#import "QueuedTrackCellView-macOS.h"

@interface QueueTableDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, copy) NSArray<QueuedTrack *> *queuedTracks;

@end

@implementation QueueTableDataSource

- (instancetype)init {
    self = [super init];
    if (self) {
        _queuedTracks = @[];
    }
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _queuedTracks.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    QueuedTrackCellView *cell = [tableView makeViewWithIdentifier:QueuedTrackCellView.reuseIdentifier owner:nil]
        ?: [[QueuedTrackCellView alloc] initWithFrame:NSZeroRect];
    [cell show:_queuedTracks[row].track];
    return cell;
}

@end

@implementation QueueTableView {
    NSTableView *_tableView;
    QueueTableDataSource *_dataSource;
    NSUUID *_Nullable _lastQueuedTrackID;
}

- (instancetype)init {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _tableView = [[NSTableView alloc] init];
        _dataSource = [[QueueTableDataSource alloc] init];
        [_tableView addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"track"]];
        _tableView.headerView = nil;
        _tableView.style = NSTableViewStylePlain;
        _tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
        _tableView.usesAlternatingRowBackgroundColors = NO;
        _tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
        _tableView.intercellSpacing = NSZeroSize;
        _tableView.rowHeight = QueuedTrackCellView.rowHeight;
        _tableView.dataSource = _dataSource;
        _tableView.delegate = _dataSource;
        self.documentView = _tableView;
        self.hasVerticalScroller = YES;
    }
    return self;
}

- (void)setQueuedTracks:(NSArray<QueuedTrack *> *)queuedTracks {
    _dataSource.queuedTracks = queuedTracks;
    [_tableView reloadData];
    QueuedTrack *last = queuedTracks.lastObject;
    if (!last || [last.identifier isEqual:_lastQueuedTrackID]) {
        _lastQueuedTrackID = last.identifier;
        return;
    }
    _lastQueuedTrackID = last.identifier;
    [self scrollToEnd];
}

- (void)scrollToEnd {
    [_tableView scrollRowToVisible:_tableView.numberOfRows - 1];
}

@end
#endif
