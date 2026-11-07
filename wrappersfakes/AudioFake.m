#import "AudioFake.h"

@implementation AudioFake {
    NSMutableArray<AudioFakeCall *> *_calls;
    NSURL *_Nullable _currentTrackURL;
    NSURL *_Nullable _nextTrackURL;
    BOOL _isPlaying;
}

@synthesize onTrackFinished = _onTrackFinished;
@synthesize onPlaybackPositionChanged = _onPlaybackPositionChanged;

- (instancetype)init {
    self = [super init];
    if (self) {
        _calls = [NSMutableArray array];
    }
    return self;
}

- (NSArray<AudioFakeCall *> *)calls {
    return [_calls copy];
}

- (void)play:(NSURL *)trackURL from:(NSTimeInterval)timeIndex thenPlay:(nullable NSURL *)nextTrackURL {
    [_calls addObject:[AudioFakeCall play:trackURL from:timeIndex thenPlay:nextTrackURL]];
    _currentTrackURL = trackURL;
    _nextTrackURL = nextTrackURL;
    _playbackPosition = timeIndex;
    _isPlaying = YES;
}

- (void)replaceNextTrackWith:(nullable NSURL *)nextTrackURL {
    [_calls addObject:[AudioFakeCall replaceNextTrack:nextTrackURL]];
    _nextTrackURL = nextTrackURL;
}

- (void)stop {
    [_calls addObject:AudioFakeCall.stop];
    _currentTrackURL = nil;
    _nextTrackURL = nil;
    _isPlaying = NO;
}

- (void)clearCalls {
    [_calls removeAllObjects];
}

// Mirrors the real wrapper, which has already advanced to the next track
// by the time it reports the finished one.
- (void)finishCurrentTrack {
    _currentTrackURL = _nextTrackURL;
    _nextTrackURL = nil;
    _playbackPosition = 0;
    _isPlaying = _currentTrackURL != nil;
    if (_onTrackFinished) {
        _onTrackFinished();
    }
}

- (void)reportPosition:(NSTimeInterval)position {
    _playbackPosition = position;
    if (_onPlaybackPositionChanged) {
        _onPlaybackPositionChanged(position);
    }
}

@end
