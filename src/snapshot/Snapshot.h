#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


NSURL *getSnapshotDirURL(id<FileSystem> fileSystem, NSError **error);


BOOL removeSnapshot(
    NSURL *snapshotDir, id<FileSystem> fileSystem, NSError **error);

BOOL takeSnapshot(NSURL *musicDir, NSURL *snapshotDir,
    id<FileSystem> fileSystem, NSError **error);


NS_ASSUME_NONNULL_END


#endif
