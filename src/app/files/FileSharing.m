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


static dispatch_queue_t
snapshot_queue(void)
{
    return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
}


static double
milliseconds_since(uint64_t start)
{
    uint64_t elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC) - start;
    return elapsed / 1e6;
}


static BOOL
remove_snapshot_and_log_time(NSURL *snapshotDir,
                             id<FileSystem> fileSystem,
                             NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL removedSnapshot = removeSnapshot(snapshotDir, fileSystem, error);
    if (removedSnapshot) {
        os_log(snapshot_log(), "Removing snapshot %{public}@ took %.1f ms",
               snapshotDir.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(), "Removing snapshot %{public}@ took %.1f ms but failed: %{public}@",
               snapshotDir.path, milliseconds_since(start), *error);
    }
    return removedSnapshot;
}


static BOOL
take_snapshot_and_log_time(NSURL *_Nullable musicDir,
                           NSURL *snapshotDir,
                           id<FileSystem> fileSystem,
                           NSError **error)
{
    if ( ! musicDir) {
        *error = no_music_root_directory_error();
        return NO;
    }

    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL tookSnapshot = takeSnapshot(musicDir, snapshotDir, fileSystem, error);
    if (tookSnapshot) {
        os_log(snapshot_log(), "Snapshot of %{public}@ to %{public}@ took %.1f ms",
               musicDir.path, snapshotDir.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(), "Snapshot of %{public}@ to %{public}@ took %.1f ms but failed: %{public}@",
               musicDir.path, snapshotDir.path, milliseconds_since(start), *error);
    }
    return tookSnapshot;
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


- (BOOL)isSharing;
{
    return FileSharingStateSharing == _state;
}


- (BOOL)isChanging;
{
    return FileSharingStateStarting == _state || FileSharingStateStopping == _state;
}


- (void)start;
{
    [self startWithCompletion:nil];
}


- (void)startWithCompletion:(nullable void (^)(void))completion;
{
    if (FileSharingStateOff != _state) {
        if (completion) completion();
        return;
    }
    [self didChangeState:FileSharingStateStarting error:nil];

    NSURL *musicDir = _store.musicRootDirectory.url;
    id<FileSystem> fileSystem = _fileSystem;
    dispatch_async(snapshot_queue(), ^{
        NSError *error = nil;
        NSURL *snapshotDir = getSnapshotDirURL(fileSystem, &error);
        BOOL tookSnapshot = snapshotDir
            && take_snapshot_and_log_time(musicDir, snapshotDir, fileSystem, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_snapshotDirURL = tookSnapshot ? snapshotDir : nil;
            [self didChangeState:(tookSnapshot ? FileSharingStateSharing : FileSharingStateOff)
                           error:error];
            if (completion) completion();
        });
    });
}


- (void)stop;
{
    [self stopWithCompletion:nil];
}


- (void)stopWithCompletion:(nullable void (^)(void))completion;
{
    if (FileSharingStateSharing != _state) {
        if (completion) completion();
        return;
    }
    [self didChangeState:FileSharingStateStopping error:nil];

    NSURL *snapshotDir = _snapshotDirURL;
    id<FileSystem> fileSystem = _fileSystem;
    dispatch_async(snapshot_queue(), ^{
        NSError *error = nil;
        remove_snapshot_and_log_time(snapshotDir, fileSystem, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_snapshotDirURL = nil;
            [self didChangeState:FileSharingStateOff error:error];
            if (completion) completion();
        });
    });
}


- (void)didChangeState:(FileSharingState)state error:(nullable NSError *)error;
{
    _state = state;
    _error = error;
    [NSNotificationCenter.defaultCenter postNotificationName:FileSharing.didChangeNotification
                                                      object:self];
}


@end


#endif
