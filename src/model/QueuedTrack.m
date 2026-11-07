#import "QueuedTrack.h"

@implementation QueuedTrack

- (instancetype)initWithTrack:(Track *)track {
    self = [super init];
    if (self) {
        _identifier = [NSUUID UUID];
        _track = track;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[QueuedTrack class]]) {
        return NO;
    }
    QueuedTrack *other = object;
    return [_identifier isEqual:other.identifier] && [_track isEqual:other.track];
}

- (NSUInteger)hash {
    return _identifier.hash * 31 + _track.hash;
}

@end
