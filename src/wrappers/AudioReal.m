#import "AudioReal.h"

#import <AVFoundation/AVFoundation.h>

static int32_t const timescale = 600;

static NSTimeInterval seconds(CMTime time)
{
    Float64 value = CMTimeGetSeconds(time);
    return isfinite(value) ? MAX(0, value) : 0;
}

@implementation AudioReal {
    AVQueuePlayer *_player;
    // The queue player still reports a finished item as current when it posts
    // the end notification, so items() cannot tell current from next.
    AVPlayerItem *_currentItem;
    AVPlayerItem *_nextItem;
    NSArray<id<NSObject>> *_finishedObservers;
    id _positionObserver;
}

@synthesize onTrackFinished = _onTrackFinished;
@synthesize onPlaybackPositionChanged = _onPlaybackPositionChanged;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _player = [[AVQueuePlayer alloc] init];
        _player.actionAtItemEnd = AVPlayerActionAtItemEndAdvance;
#if TARGET_OS_IOS
        [[AVAudioSession sharedInstance]
            setCategory:AVAudioSessionCategoryPlayback
                  error:NULL];
#endif
        [self observeFinishedItems];
        [self observePosition];
    }
    return self;
}

// The app's one instance lives as long as the app, so this never runs, let
// alone off the main thread.
- (void)dealloc
{
    for (id<NSObject> observer in _finishedObservers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
    [_player removeTimeObserver:_positionObserver];
}

- (NSTimeInterval)playbackPosition
{
    return seconds(_player.currentTime);
}

- (void)play:(NSURL *)trackURL
        from:(NSTimeInterval)timeIndex
    thenPlay:(nullable NSURL *)nextTrackURL
{
    [self removeAllItems];
    _currentItem = [self insert:trackURL];
    [self replaceNextTrackWith:nextTrackURL];
    // AVPlayer clamps a seek past the end to the item's duration.
    [_player seekToTime:CMTimeMakeWithSeconds(timeIndex, timescale)];
#if TARGET_OS_IOS
    [[AVAudioSession sharedInstance] setActive:YES error:NULL];
#endif
    [_player play];
}

- (void)replaceNextTrackWith:(nullable NSURL *)nextTrackURL
{
    if (_nextItem) {
        [_player removeItem:_nextItem];
    }
    _nextItem = nextTrackURL ? [self insert:nextTrackURL] : nil;
}

- (void)stop
{
    [_player pause];
    [self removeAllItems];
}

- (AVPlayerItem *)insert:(NSURL *)trackURL
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:trackURL];
    [_player insertItem:item afterItem:nil];
    return item;
}

- (void)removeAllItems
{
    [_player removeAllItems];
    _currentItem = nil;
    _nextItem = nil;
}

// A failed item is reported as finished so the player advances past it
// instead of waiting forever.
- (void)observeFinishedItems
{
    NSArray<NSNotificationName> *names = @[
        AVPlayerItemDidPlayToEndTimeNotification,
        AVPlayerItemFailedToPlayToEndTimeNotification,
    ];
    __weak typeof(self) weakSelf = self;
    NSMutableArray<id<NSObject>> *observers = [NSMutableArray array];
    for (NSNotificationName name in names) {
        id<NSObject> observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:name
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *notification) {
                        [weakSelf itemDidFinish:notification.object];
                    }];
        [observers addObject:observer];
    }
    _finishedObservers = [observers copy];
}

- (void)itemDidFinish:(nullable AVPlayerItem *)item
{
    if (!item || item != _currentItem) {
        return;
    }
    _currentItem = _nextItem;
    _nextItem = nil;
    if (_onTrackFinished) {
        _onTrackFinished();
    }
}

- (void)observePosition
{
    __weak typeof(self) weakSelf = self;
    _positionObserver = [_player
        addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, timescale)
                                     queue:dispatch_get_main_queue()
                                usingBlock:^(CMTime time) {
                                    [weakSelf positionDidChange:seconds(time)];
                                }];
}

- (void)positionDidChange:(NSTimeInterval)position
{
    if (_onPlaybackPositionChanged) {
        _onPlaybackPositionChanged(position);
    }
}

@end
