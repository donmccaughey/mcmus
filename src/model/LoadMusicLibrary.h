#import <Foundation/Foundation.h>

#import "FileSystem.h"
#import "LoadResult.h"

NS_ASSUME_NONNULL_BEGIN

LoadResult *loadMusicLibrary(
    NSURL *musicRootDirectory, id<FileSystem> fileSystem);

NS_ASSUME_NONNULL_END
