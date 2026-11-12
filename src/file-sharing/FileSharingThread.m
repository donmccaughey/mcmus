#import "FileSharingThread.h"

#if TARGET_OS_OSX


#import <os/log.h>
#import <time.h>

#import "FileSystem.h"
#import "LoadMusicLibrary.h"
#import "LoadResult.h"
#import "LoadTrackMetadata.h"
#import "MusicLibrary.h"
#import "Snapshot.h"


typedef void (^Reply)(NSError *_Nullable error);


static os_log_t
snapshot_log(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("cc.donm.mcmus", "snapshot");
    });
    return log;
}


static double
milliseconds_since(uint64_t start) {
    uint64_t elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC) - start;
    return elapsed / 1e6;
}


static NSArray<Track *> *
load_tracks_and_log_time(NSURL *snapshotDir, id<FileSystem> fileSystem) {
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    LoadResult *result = loadMusicLibrary(snapshotDir, fileSystem);
    NSArray<Track *> *tracks = [result.library getTracks];
    if (result.errors.count) {
        os_log(snapshot_log(), "Loaded %lu tracks from %{public}@ in %.1f ms with %lu errors",
            tracks.count, snapshotDir.path, milliseconds_since(start), result.errors.count);
    } else {
        os_log(snapshot_log(), "Loaded %lu tracks from %{public}@ in %.1f ms",
            tracks.count, snapshotDir.path, milliseconds_since(start));
    }
    return tracks;
}


static NSArray<TrackMetadata *> *
load_track_metadata_and_log_time(NSArray<Track *> *tracks, id<FileSystem> fileSystem) {
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    NSArray<NSError *> *errors = nil;
    NSArray<TrackMetadata *> *metadata = loadTrackMetadata(tracks, fileSystem, &errors);
    if (errors.count) {
        os_log(snapshot_log(), "Loaded metadata for %lu tracks in %.1f ms with %lu errors",
            metadata.count, milliseconds_since(start), errors.count);
    } else {
        os_log(snapshot_log(), "Loaded metadata for %lu tracks in %.1f ms",
            metadata.count, milliseconds_since(start));
    }
    return metadata;
}


static BOOL
remove_snapshot_and_log_time(NSURL *snapshotDir,
    id<FileSystem> fileSystem,
    NSError **error) {
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
take_snapshot_and_log_time(NSURL *musicDir,
    NSURL *snapshotDir,
    id<FileSystem> fileSystem,
    NSError **error) {
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


@implementation FileSharingThread {
    id<FileSystem> _fileSystem;
    NSURL *_musicDir;
    MusicLibrary *_musicLibrary;
    Reply _Nullable _startReply;
    Reply _Nullable _stopReply;
    BOOL _stopRequested;
}


- (instancetype)initWithFileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _fileSystem = fileSystem;
    self.name = @"cc.donm.mcmus.file-sharing";
    self.qualityOfService = NSQualityOfServiceUserInitiated;

    return self;
}


#pragma mark - Client side, called on the app's thread


- (void)startSharingMusicDirectory:(NSURL *)musicDir reply:(Reply)reply;
{
    _musicDir = musicDir;
    _startReply = [reply copy];
    [self start];
}


// performSelector:onThread: retains its argument but does not move a stack
// block to the heap, so the block must be copied before it is handed over.
- (void)stopSharingWithReply:(Reply)reply;
{
    [self performSelector:@selector(handleStop:)
                 onThread:self
               withObject:[reply copy]
            waitUntilDone:NO];
}


#pragma mark - Service side, runs on the sharing thread


- (void)main;
{
    @autoreleasepool {
        NSError *error = nil;
        NSURL *snapshotDir = getSnapshotDirURL(_fileSystem, &error);
        BOOL tookSnapshot = snapshotDir
            && take_snapshot_and_log_time(_musicDir, snapshotDir, _fileSystem, &error);
        if (!tookSnapshot) {
            [self replyToStart:error];
            return;
        }

        NSArray<Track *> *tracks = load_tracks_and_log_time(snapshotDir, _fileSystem);
        NSArray<TrackMetadata *> *metadata = load_track_metadata_and_log_time(tracks, _fileSystem);
        [self replyToStart:nil];
        (void)metadata; // TODO: build manifest CSV

        [self runUntilStopRequested];

        error = nil;
        remove_snapshot_and_log_time(snapshotDir, _fileSystem, &error);
        [self replyToStop:error];
    }
}


// The run loop returns at once when it has no input sources, so an unused
// port is attached to keep it waiting for messages. A run loop on a secondary
// thread does not drain an autorelease pool per pass; the pool inside the
// loop keeps a long sharing session from accumulating objects.
- (void)runUntilStopRequested;
{
    NSRunLoop *runLoop = NSRunLoop.currentRunLoop;
    [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    while (!_stopRequested) {
        @autoreleasepool {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
        }
    }
}


- (void)handleStop:(Reply)reply;
{
    _stopReply = reply;
    _stopRequested = YES;
}


- (void)replyToStart:(nullable NSError *)error;
{
    Reply reply = _startReply;
    _startReply = nil;
    reply(error);
}


- (void)replyToStop:(nullable NSError *)error;
{
    Reply reply = _stopReply;
    _stopReply = nil;
    reply(error);
}


@end


#endif
