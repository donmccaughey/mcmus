#import "FileSharingThread.h"

#if TARGET_OS_OSX


#import <os/log.h>
#import <time.h>

#import "FileSharingServer.h"
#import "FileSystem.h"
#import "LoadMusicLibrary.h"
#import "LoadResult.h"
#import "LoadTrackMetadata.h"
#import "Manifest.h"
#import "MusicLibrary.h"
#import "Snapshot.h"
#import "TrackMetadata.h"


typedef void (^StartReply)(uint16_t port, NSError *_Nullable error);
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
    NSURL *musicLibraryDir, id<FileSystem> fileSystem)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    LoadResult *result = loadMusicLibrary(musicLibraryDir, fileSystem);
    NSArray<Track *> *tracks = [result.library getTracks];
    if (result.errors.count) {
        os_log(snapshot_log(),
            "Loaded %lu tracks from %{public}@ in %.1f ms with %lu errors",
            tracks.count, musicLibraryDir.path, milliseconds_since(start),
            result.errors.count);
    } else {
        os_log(snapshot_log(), "Loaded %lu tracks from %{public}@ in %.1f ms",
            tracks.count, musicLibraryDir.path, milliseconds_since(start));
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


static NSURL *get_manifest_url(NSURL *workingDir)
{
    return [workingDir URLByAppendingPathComponent:@"manifest.csv"];
}


static BOOL write_manifest_and_log_time(Manifest *manifest, NSURL *workingDir,
    id<FileSystem> fileSystem, NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    NSURL *manifestURL = get_manifest_url(workingDir);
    BOOL wroteManifest = [fileSystem writeData:manifest.csv
                                        toFile:manifestURL
                                         error:error];
    if (wroteManifest) {
        os_log(snapshot_log(),
            "Wrote manifest of %lu tracks to %{public}@ in %.1f ms",
            manifest.trackCount, manifestURL.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(),
            "Writing manifest of %lu tracks took %.1f ms but failed: "
            "%{public}@",
            manifest.trackCount, milliseconds_since(start), *error);
    }
    return wroteManifest;
}


static BOOL remove_manifest(
    NSURL *workingDir, id<FileSystem> fileSystem, NSError **error)
{
    BOOL removedManifest =
        [fileSystem removeItemAtURL:get_manifest_url(workingDir) error:error];
    if (!removedManifest) {
        os_log(snapshot_log(), "Removing manifest failed: %{public}@", *error);
    }
    return removedManifest;
}


static BOOL remove_snapshot_and_log_time(
    NSURL *workingDir, id<FileSystem> fileSystem, NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    BOOL removedSnapshot = removeSnapshot(workingDir, fileSystem, error);
    if (removedSnapshot) {
        os_log(snapshot_log(), "Removing snapshot in %{public}@ took %.1f ms",
            workingDir.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(),
            "Removing snapshot in %{public}@ took %.1f ms but failed: "
            "%{public}@",
            workingDir.path, milliseconds_since(start), *error);
    }
    return removedSnapshot;
}


static NSURL *_Nullable take_snapshot_and_log_time(NSURL *musicDir,
    NSURL *workingDir, id<FileSystem> fileSystem, NSError **error)
{
    uint64_t start = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    NSURL *musicLibraryDir =
        takeSnapshot(musicDir, workingDir, fileSystem, error);
    if (musicLibraryDir) {
        os_log(snapshot_log(),
            "Snapshot of %{public}@ to %{public}@ took %.1f ms", musicDir.path,
            musicLibraryDir.path, milliseconds_since(start));
    } else {
        os_log(snapshot_log(),
            "Snapshot of %{public}@ in %{public}@ took %.1f ms but failed: "
            "%{public}@",
            musicDir.path, workingDir.path, milliseconds_since(start), *error);
    }
    return musicLibraryDir;
}


@implementation FileSharingThread {
    id<FileSystem> _fileSystem;
    id<Network> _network;
    id<Clock> _clock;
    __weak id<FileSharingClient> _client;
    NSURL *_musicDir;
    NSURL *_workingDir;
    MusicLibrary *_musicLibrary;
    StartReply _Nullable _startReply;
    Reply _Nullable _stopReply;
    BOOL _stopRequested;
}


- (instancetype)initWithFileSystem:(id<FileSystem>)fileSystem
                           network:(id<Network>)network
                             clock:(id<Clock>)clock
                            client:(nullable id<FileSharingClient>)client;
{
    self = [super init];
    if (!self) return nil;

    _fileSystem = fileSystem;
    _network = network;
    _clock = clock;
    _client = client;
    self.name = @"cc.donm.mcmus.file-sharing";
    self.qualityOfService = NSQualityOfServiceUserInitiated;

    return self;
}


#pragma mark - Client side, called on the app's thread


- (void)startSharingMusicDirectory:(NSURL *)musicDir
                  workingDirectory:(NSURL *)workingDir
                             reply:(StartReply)reply;
{
    _musicDir = musicDir;
    _workingDir = workingDir;
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
        NSURL *musicLibraryDir = take_snapshot_and_log_time(
            _musicDir, _workingDir, _fileSystem, &error);
        if (!musicLibraryDir) {
            [self replyToStartWithPort:0 error:error];
            return;
        }

        NSArray<Track *> *tracks =
            load_tracks_and_log_time(musicLibraryDir, _fileSystem);
        NSArray<TrackMetadata *> *metadata =
            load_track_metadata_and_log_time(tracks, _fileSystem,
                ^(NSUInteger tracksLoaded, NSUInteger totalTracks) {
                    [self->_client didLoadMetadataForTracks:tracksLoaded
                                                    ofTotal:totalTracks];
                });
        Manifest *manifest =
            [[Manifest alloc] initWithTrackMetadata:metadata
                              musicLibraryDirectory:musicLibraryDir];
        BOOL wroteManifest = write_manifest_and_log_time(
            manifest, _workingDir, _fileSystem, &error);
        FileSharingServer *server = wroteManifest
            ? [self startServerWithManifest:manifest error:&error]
            : nil;
        if (!server) {
            NSError *cleanUpError = nil;
            if (wroteManifest) {
                remove_manifest(_workingDir, _fileSystem, &cleanUpError);
            }
            remove_snapshot_and_log_time(
                _workingDir, _fileSystem, &cleanUpError);
            [self replyToStartWithPort:0 error:error];
            return;
        }
        [self replyToStartWithPort:server.port error:nil];

        [self runUntilStopRequested];

        [server stop];
        [self replyToStop:[self removeManifestAndSnapshot]];
    }
}


- (nullable FileSharingServer *)startServerWithManifest:(Manifest *)manifest
                                                  error:(NSError **)error;
{
    FileSharingServer *server =
        [[FileSharingServer alloc] initWithNetwork:_network
                                             clock:_clock
                                        fileSystem:_fileSystem
                                          manifest:manifest];
    server.onWaitingForClient = ^{ [self->_client serverIsWaitingForClient]; };
    server.onClientConnected = ^(NSString *deviceName) {
        [self->_client serverDidConnectClient:deviceName];
    };
    return [server startAndReturnError:error] ? server : nil;
}


// Both are attempted even when the first fails; the first error is returned.
- (nullable NSError *)removeManifestAndSnapshot;
{
    NSError *manifestError = nil;
    NSError *snapshotError = nil;
    BOOL removedManifest =
        remove_manifest(_workingDir, _fileSystem, &manifestError);
    BOOL removedSnapshot =
        remove_snapshot_and_log_time(_workingDir, _fileSystem, &snapshotError);
    if (!removedManifest) return manifestError;
    return removedSnapshot ? nil : snapshotError;
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


- (void)replyToStartWithPort:(uint16_t)port error:(nullable NSError *)error;
{
    StartReply reply = _startReply;
    _startReply = nil;
    reply(port, error);
}


- (void)replyToStop:(nullable NSError *)error;
{
    Reply reply = _stopReply;
    _stopReply = nil;
    reply(error);
}


@end


#endif
