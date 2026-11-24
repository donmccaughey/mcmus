#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


BOOL removeSnapshot(
    NSURL *workingDir, id<FileSystem> fileSystem, NSError **error);

// Returns the directory inside the working directory that holds the snapshot
// of the music directory, or nil on failure.
NSURL *_Nullable takeSnapshot(NSURL *musicDir,
    NSURL *workingDir,
    id<FileSystem> fileSystem,
    NSError **error);


NS_ASSUME_NONNULL_END


#endif
