#import "Queue.h"

@implementation Queue {
    NSMutableArray<QueuedTrack *> *_queuedTracks;
}

+ (NSNotificationName)didChangeNotification {
    return @"QueueDidChange";
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queuedTracks = [NSMutableArray array];
    }
    return self;
}

- (NSArray<QueuedTrack *> *)queuedTracks {
    return [_queuedTracks copy];
}

- (NSArray<Track *> *)tracks {
    NSMutableArray<Track *> *tracks = [NSMutableArray arrayWithCapacity:_queuedTracks.count];
    for (QueuedTrack *queuedTrack in _queuedTracks) {
        [tracks addObject:queuedTrack.track];
    }
    return tracks;
}

- (BOOL)isEmpty {
    return _queuedTracks.count == 0;
}

- (void)add:(id<FolderChild>)child {
    [self addChildren:@[child]];
}

- (void)addChildren:(NSArray<id<FolderChild>> *)children {
    NSMutableArray<Track *> *tracks = [NSMutableArray array];
    for (id<FolderChild> child in children) {
        [tracks addObjectsFromArray:child.trackDescendants];
    }
    if (tracks.count == 0) {
        return;
    }
    for (Track *track in tracks) {
        [_queuedTracks addObject:[[QueuedTrack alloc] initWithTrack:track]];
    }
    [self postDidChange];
}

- (void)removeFirst {
    if (_queuedTracks.count == 0) {
        return;
    }
    [_queuedTracks removeObjectAtIndex:0];
    [self postDidChange];
}

- (void)clear {
    if (_queuedTracks.count == 0) {
        return;
    }
    [_queuedTracks removeAllObjects];
    [self postDidChange];
}

- (void)postDidChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:Queue.didChangeNotification object:self];
}

@end
