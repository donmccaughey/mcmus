#import "TrackMetadata.h"

@implementation TrackMetadata

- (instancetype)initWithRelativePath:(NSString *)relativePath
                                size:(unsigned long long)size
                            fileHash:(NSUInteger)fileHash;
{
    self = [super init];
    if (!self) return nil;

    _relativePath = [relativePath copy];
    _size = size;
    _fileHash = fileHash;

    return self;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"TrackMetadata(%@, %llu, 0x%016lx)",
        _relativePath, _size, (unsigned long)_fileHash];
}

@end
