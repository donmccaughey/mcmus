#import "TrackMetadata.h"

@implementation TrackMetadata

- (instancetype)initWithTrack:(Track *)track
                         size:(unsigned long long)size
                     fileHash:(NSUInteger)fileHash;
{
    self = [super init];
    if ( ! self) return nil;

    _track = track;
    _size = size;
    _fileHash = fileHash;

    return self;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"TrackMetadata(%@, %llu, 0x%016lx)",
        _track.path, _size, (unsigned long)_fileHash];
}

@end
