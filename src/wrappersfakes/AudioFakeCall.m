#import "AudioFakeCall.h"

typedef NS_ENUM(NSInteger, AudioFakeCallKind) {
    AudioFakeCallKindPlay,
    AudioFakeCallKindReplaceNextTrack,
    AudioFakeCallKindStop,
};

// [nil isEqual:nil] is NO, so nullable properties need their own comparison.
static BOOL equalOrBothNil(id _Nullable a, id _Nullable b) {
    return a == b || [a isEqual:b];
}

@implementation AudioFakeCall {
    AudioFakeCallKind _kind;
    NSURL *_Nullable _trackURL;
    NSTimeInterval _timeIndex;
    NSURL *_Nullable _nextTrackURL;
}

- (instancetype)initWithKind:(AudioFakeCallKind)kind
                    trackURL:(nullable NSURL *)trackURL
                   timeIndex:(NSTimeInterval)timeIndex
                nextTrackURL:(nullable NSURL *)nextTrackURL {
    self = [super init];
    if (self) {
        _kind = kind;
        _trackURL = [trackURL copy];
        _timeIndex = timeIndex;
        _nextTrackURL = [nextTrackURL copy];
    }
    return self;
}

+ (AudioFakeCall *)play:(NSURL *)trackURL from:(NSTimeInterval)timeIndex thenPlay:(nullable NSURL *)nextTrackURL {
    return [[AudioFakeCall alloc] initWithKind:AudioFakeCallKindPlay
                                      trackURL:trackURL
                                     timeIndex:timeIndex
                                  nextTrackURL:nextTrackURL];
}

+ (AudioFakeCall *)replaceNextTrack:(nullable NSURL *)nextTrackURL {
    return [[AudioFakeCall alloc] initWithKind:AudioFakeCallKindReplaceNextTrack
                                      trackURL:nil
                                     timeIndex:0
                                  nextTrackURL:nextTrackURL];
}

+ (AudioFakeCall *)stop {
    return [[AudioFakeCall alloc] initWithKind:AudioFakeCallKindStop trackURL:nil timeIndex:0 nextTrackURL:nil];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[AudioFakeCall class]]) {
        return NO;
    }
    AudioFakeCall *other = object;
    return _kind == other->_kind
        && equalOrBothNil(_trackURL, other->_trackURL)
        && _timeIndex == other->_timeIndex
        && equalOrBothNil(_nextTrackURL, other->_nextTrackURL);
}

- (NSUInteger)hash {
    NSUInteger hash = (NSUInteger)_kind;
    hash = hash * 31 + _trackURL.hash;
    hash = hash * 31 + [@(_timeIndex) hash];
    hash = hash * 31 + _nextTrackURL.hash;
    return hash;
}

- (NSString *)description {
    switch (_kind) {
        case AudioFakeCallKindPlay:
            return [NSString stringWithFormat:@"play(%@, from: %g, thenPlay: %@)",
                    _trackURL.path, _timeIndex, _nextTrackURL.path ?: @"nil"];
        case AudioFakeCallKindReplaceNextTrack:
            return [NSString stringWithFormat:@"replaceNextTrack(%@)", _nextTrackURL.path ?: @"nil"];
        case AudioFakeCallKindStop:
            return @"stop";
    }
}

@end
