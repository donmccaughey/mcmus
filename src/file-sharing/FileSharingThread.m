#import "FileSharingThread.h"

#if TARGET_OS_OSX


#import <os/log.h>
#import <time.h>

#import "CSV.h"
#import "FileSystem.h"
#import "LoadMusicLibrary.h"
#import "LoadResult.h"
#import "LoadTrackMetadata.h"
#import "MusicLibrary.h"
#import "Snapshot.h"
#import "TrackMetadata.h"


typedef void (^Reply)(NSError *_Nullable error);


static os_log_t snapshot_log(void)
{
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(
        &once, ^{ log = os_log_create("cc.donm.mcmus", "snapshot"); });
    return log;
}


static double milliseconds_since(uint64_t start)
{
    uint64_t elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC) - start;
    return elapsed / 1e6;
}


static NSArray<Track *> *load_tracks_and_log_time(
    NSURL *snapshotDir, id<FileSystem> fileSystem)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    LoadResult *result = loadMusicLibrary(snapshotDir, fileSystem);
    NSArray<Track *> *tracks = [result.library getTracks];
    if (result.errors.count) {
        os_log(snapshot_log(),
            "Loaded %lu tracks from %{public}@ in %.1f ms with %lu errors",
            tracks.count, snapshotDir.path, milliseconds_since(start),
            result.errors.count);
    } else {
        os_log(snapshot_log(), "Loaded %lu tracks from %{public}@ in %.1f ms",
            tracks.count, snapshotDir.path, milliseconds_since(start));
    }
    return tracks;
}


static NSArray<TrackMetadata *> *load_track_metadata_and_log_time(
    NSArray<Track *> *tracks, id<FileSystem> fileSystem,
    LoadTrackMetadataProgress progress)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    NSArray<NSError *> *errors = nil;
    NSArray<TrackMetadata *> *metadata =
        loadTrackMetadata(tracks, fileSystem, progress, &errors);
    if (errors.count) {
        os_log(snapshot_log(),
            "Loaded metadata for %lu tracks in %.1f ms with %lu errors",
            metadata.count, milliseconds_since(start), errors.count);
    } else {
        os_log(snapshot_log(), "Loaded metadata for %lu tracks in %.1f ms",
            metadata.count, milliseconds_since(start));
    }
    return metadata;
}


static NSString *path_relative_to_snapshot(Track *track, NSURL *snapshotDir)
{
    NSString *prefix = [snapshotDir.path stringByAppendingString:@"/"];
    if (![track.path hasPrefix:prefix]) return track.path;
    return [track.path substringFromIndex:prefix.length];
}


static NSArray<NSArray<NSString *> *> *manifest_records(
    NSArray<TrackMetadata *> *metadata, NSURL *snapshotDir)
{
    NSMutableArray<NSArray<NSString *> *> *records =
        [NSMutableArray arrayWithCapacity:metadata.count + 1];
    [records addObject:@[@"path", @"size", @"hash"]];
    for (TrackMetadata *trackMetadata in metadata) {
        [records addObject:@[
            path_relative_to_snapshot(trackMetadata.track, snapshotDir),
            [NSString stringWithFormat:@"%llu", trackMetadata.size],
            [NSString stringWithFormat:@"%lu", trackMetadata.fileHash],
        ]];
    }
    return records;
}


static BOOL write_manifest_and_log_time(NSArray<TrackMetadata *> *metadata,
    NSURL *snapshotDir, id<FileSystem> fileSystem, NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    NSURL *appSupportDir =
        [fileSystem getApplicationSupportDirectoryURLAndReturnError:error];
    NSURL *manifest =
        [appSupportDir URLByAppendingPathComponent:@"manifest.csv"];
    BOOL wroteManifest = manifest &&
        [fileSystem
            writeData:generateCSV(manifest_records(metadata, snapshotDir))
               toFile:manifest
                error:error];
    if (wroteManifest) {
        os_log(snapshot_log(),
            "Wrote manifest of %lu tracks to %{public}@ in %.1f ms",
            metadata.count, manifest.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(),
            "Writing manifest of %lu tracks took %.1f ms but failed: "
            "%{public}@",
            metadata.count, milliseconds_since(start), *error);
    }
    return wroteManifest;
}


static BOOL remove_snapshot_and_log_time(
    NSURL *snapshotDir, id<FileSystem> fileSystem, NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL removedSnapshot = removeSnapshot(snapshotDir, fileSystem, error);
    if (removedSnapshot) {
        os_log(snapshot_log(), "Removing snapshot %{public}@ took %.1f ms",
            snapshotDir.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(),
            "Removing snapshot %{public}@ took %.1f ms but failed: %{public}@",
            snapshotDir.path, milliseconds_since(start), *error);
    }
    return removedSnapshot;
}


static BOOL take_snapshot_and_log_time(NSURL *musicDir, NSURL *snapshotDir,
    id<FileSystem> fileSystem, NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL tookSnapshot = takeSnapshot(musicDir, snapshotDir, fileSystem, error);
    if (tookSnapshot) {
        os_log(snapshot_log(),
            "Snapshot of %{public}@ to %{public}@ took %.1f ms", musicDir.path,
            snapshotDir.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(),
            "Snapshot of %{public}@ to %{public}@ took %.1f ms but failed: "
            "%{public}@",
            musicDir.path, snapshotDir.path, milliseconds_since(start), *error);
    }
    return tookSnapshot;
}


@implementation FileSharingThread {
    id<FileSystem> _fileSystem;
    __weak id<FileSharingClient> _client;
    NSURL *_musicDir;
    MusicLibrary *_musicLibrary;
    Reply _Nullable _startReply;
    Reply _Nullable _stopReply;
    BOOL _stopRequested;
}


- (instancetype)initWithFileSystem:(id<FileSystem>)fileSystem
                            client:(nullable id<FileSharingClient>)client;
{
    self = [super init];
    if (!self) return nil;

    _fileSystem = fileSystem;
    _client = client;
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
            && take_snapshot_and_log_time(
                _musicDir, snapshotDir, _fileSystem, &error);
        if (!tookSnapshot) {
            [self replyToStart:error];
            return;
        }

        NSArray<Track *> *tracks =
            load_tracks_and_log_time(snapshotDir, _fileSystem);
        NSArray<TrackMetadata *> *metadata =
            load_track_metadata_and_log_time(tracks, _fileSystem,
                ^(NSUInteger tracksLoaded, NSUInteger totalTracks) {
                    [self->_client didLoadMetadataForTracks:tracksLoaded
                                                    ofTotal:totalTracks];
                });
        BOOL wroteManifest = write_manifest_and_log_time(
            metadata, snapshotDir, _fileSystem, &error);
        if (!wroteManifest) {
            NSError *removeError = nil;
            remove_snapshot_and_log_time(
                snapshotDir, _fileSystem, &removeError);
            [self replyToStart:error];
            return;
        }
        [self replyToStart:nil];

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
            [runLoop runMode:NSDefaultRunLoopMode
                  beforeDate:NSDate.distantFuture];
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
