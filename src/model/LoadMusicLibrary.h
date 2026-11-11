#import <Foundation/Foundation.h>

#import "FileSystem.h"
#import "LoadResult.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, LoadOptions) {
    LoadOptionsNone = 0,
    LoadOptionsTrackSize = 1 << 0,
};

LoadResult *loadMusicLibrary(NSURL *musicRootDirectory,
                             LoadOptions options,
                             id<FileSystem> fileSystem);

NS_ASSUME_NONNULL_END
