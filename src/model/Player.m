#import "Player.h"

@implementation Player {
    BOOL _isMutatingQueue;
}

+ (NSNotificationName)didChangeNotification {
    return @"PlayerDidChange";
}

- (instancetype)initWithAudio:(id<Audio>)audio;
{
    self = [super init];
    if ( ! self) return nil;
    
    _audio = audio;
    _queue = [[Queue alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queueDidChange)
                                                 name:Queue.didChangeNotification
                                               object:_queue];
    __weak typeof(self) weakSelf = self;
    audio.onTrackFinished = ^{
        [weakSelf audioDidFinishCurrentTrack];
    };
    audio.onPlaybackPositionChanged = ^(NSTimeInterval position) {
        [weakSelf audioPositionDidChangeTo:position];
    };
    
    return self;
}

- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (nullable Track *)currentTrack {
    return _queue.queuedTracks.firstObject.track;
}

- (nullable Track *)nextTrack {
    NSArray<QueuedTrack *> *queuedTracks = _queue.queuedTracks;
    return queuedTracks.count > 1 ? queuedTracks[1].track : nil;
}

- (void)play {
    Track *currentTrack = self.currentTrack;
    if (!currentTrack || _isPlaying) {
        return;
    }
    [_audio play:currentTrack.url from:_timeIndex thenPlay:self.nextTrack.url];
    [self updateIsPlaying:YES];
}

- (void)stop {
    if (_queue.isEmpty || !_isPlaying) {
        return;
    }
    _timeIndex = _audio.playbackPosition;
    [self stopAudio];
}

- (void)back {
    Track *currentTrack = self.currentTrack;
    if (!currentTrack) {
        return;
    }
    _timeIndex = 0;
    if (_isPlaying) {
        [_audio play:currentTrack.url from:0 thenPlay:self.nextTrack.url];
    }
}

- (void)next {
    if (_queue.isEmpty) {
        return;
    }
    _timeIndex = 0;
    [self mutateQueue:^{
        [self->_queue removeFirst];
    }];
    if (!_isPlaying) {
        return;
    }
    Track *currentTrack = self.currentTrack;
    if (currentTrack) {
        [_audio play:currentTrack.url from:0 thenPlay:self.nextTrack.url];
    } else {
        [self stopAudio];
    }
}

- (void)clear {
    if (_queue.isEmpty) {
        return;
    }
    _timeIndex = 0;
    [self mutateQueue:^{
        [self->_queue clear];
    }];
    if (_isPlaying) {
        [self stopAudio];
    }
}

- (void)stopAudio {
    [_audio stop];
    [self updateIsPlaying:NO];
}

// Every caller has checked that the value changes, so this posts once per
// command, after the command's other state is settled.
- (void)updateIsPlaying:(BOOL)isPlaying {
    _isPlaying = isPlaying;
    [[NSNotificationCenter defaultCenter] postNotificationName:Player.didChangeNotification object:self];
}

// The player's own commands tell the audio wrapper what to play next
// themselves, so only changes made by others need syncing here.
- (void)mutateQueue:(void (NS_NOESCAPE ^)(void))mutate {
    _isMutatingQueue = YES;
    mutate();
    _isMutatingQueue = NO;
}

- (void)queueDidChange {
    if (!_isPlaying || _isMutatingQueue) {
        return;
    }
    [_audio replaceNextTrackWith:self.nextTrack.url];
}

// The audio wrapper has already moved on to the next track, so only the
// queue needs to catch up.
- (void)audioDidFinishCurrentTrack {
    if (!_isPlaying) {
        return;
    }
    _timeIndex = 0;
    [self mutateQueue:^{
        [self->_queue removeFirst];
    }];
    if (_queue.isEmpty) {
        [self updateIsPlaying:NO];
    } else {
        [_audio replaceNextTrackWith:self.nextTrack.url];
    }
}

- (void)audioPositionDidChangeTo:(NSTimeInterval)position {
    if (_isPlaying) {
        _timeIndex = position;
    }
}

@end
