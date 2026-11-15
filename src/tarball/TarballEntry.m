#import "TarballEntry.h"


@implementation TarballEntry


- (instancetype)initWithRelativePath:(NSString *)relativePath
                                size:(unsigned long long)size
                               mtime:(time_t)mtime;
{
    self = [super init];
    if (!self) return nil;

    _relativePath = [relativePath copy];
    _size = size;
    _mtime = mtime;

    return self;
}


@end
