#import "AudioDemo.h"


@implementation AudioDemo
{
    NSURL *_demoTrackURL;
    id<Audio> _audio;
}


- (instancetype)initWithDemoTrackURL:(NSURL *)demoTrackURL
                               audio:(id<Audio>)audio;
{
    self = [super init];
    if ( ! self) return nil;

    _demoTrackURL = [demoTrackURL copy];
    _audio = audio;

    return self;
}


- (NSTimeInterval)playbackPosition;
{
    return _audio.playbackPosition;
}


- (void (^_Nullable)(void))onTrackFinished;
{
    return _audio.onTrackFinished;
}


- (void)setOnTrackFinished:(void (^_Nullable)(void))onTrackFinished;
{
    _audio.onTrackFinished = onTrackFinished;
}


- (void (^_Nullable)(NSTimeInterval))onPlaybackPositionChanged;
{
    return _audio.onPlaybackPositionChanged;
}


- (void)setOnPlaybackPositionChanged:(void (^_Nullable)(NSTimeInterval))onPlaybackPositionChanged;
{
    _audio.onPlaybackPositionChanged = onPlaybackPositionChanged;
}


- (void)play:(NSURL *)trackURL from:(NSTimeInterval)timeIndex thenPlay:(nullable NSURL *)nextTrackURL;
{
    [_audio play:_demoTrackURL from:timeIndex thenPlay:[self demoTrackFor:nextTrackURL]];
}


- (void)replaceNextTrackWith:(nullable NSURL *)nextTrackURL;
{
    [_audio replaceNextTrackWith:[self demoTrackFor:nextTrackURL]];
}


- (void)stop;
{
    [_audio stop];
}


- (nullable NSURL *)demoTrackFor:(nullable NSURL *)trackURL;
{
    return trackURL ? _demoTrackURL : nil;
}


@end
