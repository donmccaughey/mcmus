#import "FileSyncingState.h"

#import "Manifest.h"


@implementation FileSyncingState


- (instancetype)initWithLocalManifestPath:(NSURL *)localManifestPath
                            andFileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

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

    // TODO: compare local and server manifest
}


@end
