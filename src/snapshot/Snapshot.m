#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import "FileSystem.h"
#import "Snapshot.h"


static BOOL is_missing_file_error(NSError *error)
{
    return (
        NSCocoaErrorDomain == error.domain
        && NSFileNoSuchFileError == error.code
    );
}


static BOOL remove_dir_if_exists(
    NSURL *dir, id<FileSystem> fileSystem, NSError **error
)
{
    if ([fileSystem removeItemAtURL:dir error:error]) return YES;
    if (is_missing_file_error(*error)) {
        *error = nil;
        return YES;
    }
    return NO;
}


static NSURL *snapshot_url(NSURL *workingDir)
{
    return [workingDir URLByAppendingPathComponent:@"snapshot"];
}


BOOL removeSnapshot(
    NSURL *workingDir, id<FileSystem> fileSystem, NSError **error
)
{
    return remove_dir_if_exists(snapshot_url(workingDir), fileSystem, error);
}


NSURL *_Nullable takeSnapshot(
    NSURL *musicDir,
    NSURL *workingDir,
    id<FileSystem> fileSystem,
    NSError **error
)
{
    NSURL *snapshotURL = snapshot_url(workingDir);
    BOOL removed = remove_dir_if_exists(snapshotURL, fileSystem, error);
    if (!removed) return nil;

    BOOL cloned = [fileSystem cloneFile:musicDir
                                 toFile:snapshotURL
                                  error:error];
    if (cloned) {
        if (error) *error = nil;
        return snapshotURL;
    } else {
        return nil;
    }
}


#endif
