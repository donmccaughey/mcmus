#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import "FileSystem.h"
#import "Snapshot.h"


static BOOL is_missing_file_error(NSError *error)
{
    return (NSCocoaErrorDomain == error.domain
        && NSFileNoSuchFileError == error.code);
}


static BOOL remove_dir_if_exists(
    NSURL *dir, id<FileSystem> fileSystem, NSError **error)
{
    if ([fileSystem removeItemAtURL:dir error:error]) return YES;
    if (is_missing_file_error(*error)) {
        *error = nil;
        return YES;
    }
    return NO;
}


NSURL *getSnapshotDirURL(id<FileSystem> fileSystem, NSError **error)
{
    NSURL *appSupportDir =
        [fileSystem getApplicationSupportDirectoryURLAndReturnError:error];
    return [appSupportDir URLByAppendingPathComponent:@"snapshot"];
}


BOOL removeSnapshot(
    NSURL *snapshotDir, id<FileSystem> fileSystem, NSError **error)
{
    return remove_dir_if_exists(snapshotDir, fileSystem, error);
}


BOOL takeSnapshot(NSURL *musicDir, NSURL *snapshotDir,
    id<FileSystem> fileSystem, NSError **error)
{
    BOOL removed = remove_dir_if_exists(snapshotDir, fileSystem, error);
    if (!removed) return NO;

    BOOL cloned = [fileSystem cloneFile:musicDir toFile:snapshotDir
                                  error:error];
    if (cloned) {
        *error = nil;
        return YES;
    } else {
        return NO;
    }
}


#endif
