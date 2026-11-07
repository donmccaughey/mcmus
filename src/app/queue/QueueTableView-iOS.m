#import "QueueTableView-iOS.h"

#if TARGET_OS_IOS
#import "QueuedTrackCellView-iOS.h"
#import "UIView+FillingSubview.h"

@interface QueueTableDataSource : NSObject <UITableViewDataSource>

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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _queuedTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    QueuedTrackCellView *cell = [tableView dequeueReusableCellWithIdentifier:QueuedTrackCellView.reuseIdentifier
                                                                forIndexPath:indexPath];
    [cell show:_queuedTracks[indexPath.row].track];
    return cell;
}

@end

@implementation QueueTableView {
    UITableView *_tableView;
    QueueTableDataSource *_dataSource;
    NSUUID *_Nullable _lastQueuedTrackID;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _dataSource = [[QueueTableDataSource alloc] init];
        _tableView.allowsSelection = NO;
        [_tableView registerClass:[QueuedTrackCellView class] forCellReuseIdentifier:QueuedTrackCellView.reuseIdentifier];
        _tableView.dataSource = _dataSource;
        [self updateRowHeight];
        [self addFillingSubview:_tableView];
        [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class]
                           withAction:@selector(contentSizeCategoryDidChange)];
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
    // Tracks queued before this view came on screen, as when a second
    // window opens, were not just added and have no size to scroll in.
    if (!self.window) {
        return;
    }
    NSIndexPath *lastRow = [NSIndexPath indexPathForRow:_dataSource.queuedTracks.count - 1 inSection:0];
    [_tableView scrollToRowAtIndexPath:lastRow atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

- (void)contentSizeCategoryDidChange {
    [self updateRowHeight];
    [_tableView reloadData];
}

- (void)updateRowHeight {
    _tableView.rowHeight = [QueuedTrackCellView rowHeightForTraitCollection:self.traitCollection];
}

@end
#endif
