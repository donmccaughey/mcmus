#import "FileSyncingState.h"

#import "Manifest.h"


@implementation FileSyncingState


- (instancetype)initWithLocalManifestPath:(NSURL *)localManifestPath
                            andFileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _removedTracks = @[];
    _addedTracks = @[];
    _changedTracks = @[];

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
    _changedTracks = [_localManifest tracksChangedIn:_serverManifest];
    _modifiedTrackCount =
        _removedTracks.count + _addedTracks.count + _changedTracks.count;
}


@end
