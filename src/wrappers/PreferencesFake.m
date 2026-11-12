#import "PreferencesFake.h"

@implementation PreferencesFake

- (instancetype)initWithMusicRootDirectoryBookmark:
    (nullable NSData *)musicRootDirectoryBookmark
{
    self = [super init];
    if (self) {
        _musicRootDirectoryBookmark = [musicRootDirectoryBookmark copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithMusicRootDirectoryBookmark:nil];
}

- (nullable NSData *)getMusicRootDirectoryBookmark
{
    return _musicRootDirectoryBookmark;
}

@end
