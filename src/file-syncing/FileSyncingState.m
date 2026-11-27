#import "FileSyncingState.h"

#import "Manifest.h"
#import "TrackMetadata.h"


// Matches the most the server will send in one tarball of several tracks.
static const unsigned long long maxTarballSize = 100ULL * 1024 * 1024;


@implementation FileSyncingState


- (instancetype)initWithLocalManifestPath:(NSURL *)localManifestPath
                            andFileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _removedTracks = @[];
    _addedTracks = @[];
    _changedTracks = @[];
    _tarballs = @[];

    _localManifest = [Manifest newWithCSVPath:localManifestPath
                                   fileSystem:fileSystem
                                        error:NULL]
        ?: [Manifest new];

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)updateWithServerManifest:(Manifest *)serverManifest;
{
    _serverManifest = serverManifest;

    _removedTracks = [_localManifest tracksMissingFrom:_serverManifest];
    _addedTracks = [_serverManifest tracksMissingFrom:_localManifest];
    _changedTracks = [_serverManifest tracksChangedFrom:_localManifest];
    _tarballs = [self makeTarballs];
    _modifiedTrackCount =
        _removedTracks.count + _addedTracks.count + _changedTracks.count;
}


- (NSArray<NSArray<NSString *> *> *)makeTarballs;
{
    NSMutableArray<NSArray<NSString *> *> *tarballs = [NSMutableArray array];
    NSMutableArray<NSString *> *tarball = [NSMutableArray array];
    unsigned long long tarballSize = 0;

    for (TrackMetadata *download in [self sortedDownloads]) {
        BOOL wouldOverflow = tarballSize + download.size > maxTarballSize;
        if (wouldOverflow && tarball.count) {
            [tarballs addObject:tarball];
            tarball = [NSMutableArray array];
            tarballSize = 0;
        }
        [tarball addObject:download.relativePath];
        tarballSize += download.size;
    }
    if (tarball.count) [tarballs addObject:tarball];

    return tarballs;
}


- (NSArray<TrackMetadata *> *)sortedDownloads;
{
    NSArray<TrackMetadata *> *downloads =
        [_addedTracks arrayByAddingObjectsFromArray:_changedTracks];
    return [downloads sortedArrayUsingComparator:^(
                          TrackMetadata *left, TrackMetadata *right
    ) { return [left.relativePath compare:right.relativePath]; }];
}


@end
