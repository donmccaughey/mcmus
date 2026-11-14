#import "TrackMetadata.h"

@implementation TrackMetadata

- (instancetype)initWithTrack:(Track *)track
                         size:(unsigned long long)size
                        mtime:(time_t)mtime
                     fileHash:(NSUInteger)fileHash;
{
    self = [super init];
    if (!self) return nil;

    _track = track;
    _size = size;
    _mtime = mtime;
    _fileHash = fileHash;

    return self;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"TrackMetadata(%@, %llu, %ld, 0x%016lx)",
        _track.path, _size, (long)_mtime, (unsigned long)_fileHash];
}

@end
