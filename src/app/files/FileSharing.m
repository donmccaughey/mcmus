#import "FileSharing.h"

#if TARGET_OS_OSX


#import <os/log.h>
#import <time.h>

#import "FileSystemReal.h"
#import "Snapshot.h"


static NSErrorDomain const FileSharingErrorDomain = @"FileSharingErrorDomain";

typedef NS_ENUM(NSInteger, FileSharingErrorCode) {
    FileSharingErrorCodeNoMusicRootDirectory = 1,
};


static NSError *
no_music_root_directory_error(void)
{
    return [NSError errorWithDomain:FileSharingErrorDomain
                               code:FileSharingErrorCodeNoMusicRootDirectory
                           userInfo:@{
        NSLocalizedDescriptionKey: @"No music root directory.",
    }];
}


static os_log_t
snapshot_log(void)
{
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("cc.donm.mcmus", "snapshot");
    });
    return log;
}


static double
milliseconds_since(uint64_t start)
{
    uint64_t elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC) - start;
    return elapsed / 1e6;
}


@implementation FileSharing
{
    MusicLibraryStore *_store;
    id<FileSystem> _fileSystem;
    NSURL *_Nullable _snapshotDirURL;
}


+ (NSNotificationName)didChangeNotification;
{
    return @"FileSharingDidChange";
}


- (instancetype)initWithStore:(MusicLibraryStore *)store
                   fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (self) {
        _store = store;
        _fileSystem = fileSystem;
    }
    return self;
}


- (instancetype)initWithStore:(MusicLibraryStore *)store;
{
    return [self initWithStore:store fileSystem:[[FileSystemReal alloc] init]];
}


- (void)start;
{
    NSError *error = nil;
    _snapshotDirURL = getSnapshotDirURL(_fileSystem, &error);
    BOOL tookSnapshot = _snapshotDirURL && [self takeSnapshotAndReturnError:&error];
    [self didChangeIsSharing:tookSnapshot error:error];
}


- (void)stop;
{
    NSError *error = nil;
    if (_snapshotDirURL) {
        [self removeSnapshotAndReturnError:&error];
        _snapshotDirURL = nil;
    }
    [self didChangeIsSharing:NO error:error];
}


- (BOOL)removeSnapshotAndReturnError:(NSError **)error;
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL removedSnapshot = removeSnapshot(_snapshotDirURL, _fileSystem, error);
    if (removedSnapshot) {
        os_log(snapshot_log(), "Removing snapshot %{public}@ took %.1f ms",
               _snapshotDirURL.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(), "Removing snapshot %{public}@ took %.1f ms but failed: %{public}@",
               _snapshotDirURL.path, milliseconds_since(start), *error);
    }
    return removedSnapshot;
}


- (BOOL)takeSnapshotAndReturnError:(NSError **)error;
{
    NSURL *musicDir = _store.musicRootDirectory.url;
    if ( ! musicDir) {
        *error = no_music_root_directory_error();
        return NO;
    }

    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL tookSnapshot = takeSnapshot(musicDir, _snapshotDirURL, _fileSystem, error);
    if (tookSnapshot) {
        os_log(snapshot_log(), "Snapshot of %{public}@ to %{public}@ took %.1f ms",
               musicDir.path, _snapshotDirURL.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(), "Snapshot of %{public}@ to %{public}@ took %.1f ms but failed: %{public}@",
               musicDir.path, _snapshotDirURL.path, milliseconds_since(start), *error);
    }
    return tookSnapshot;
}


- (void)didChangeIsSharing:(BOOL)isSharing error:(nullable NSError *)error;
{
    _isSharing = isSharing;
    _error = error;
    [NSNotificationCenter.defaultCenter postNotificationName:FileSharing.didChangeNotification
                                                      object:self];
}


@end


#endif
