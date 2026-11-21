#import "TrackMetadata.h"

@implementation TrackMetadata

- (instancetype)initWithRelativePath:(NSString *)relativePath
                                size:(unsigned long long)size
                               mtime:(time_t)mtime
                            fileHash:(NSUInteger)fileHash;
{
    self = [super init];
    if (!self) return nil;

    _relativePath = [relativePath copy];
    _size = size;
    _mtime = mtime;
    _fileHash = fileHash;

    return self;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"TrackMetadata(%@, %llu, %ld, 0x%016lx)",
        _relativePath, _size, (long)_mtime, (unsigned long)_fileHash];
}

@end
