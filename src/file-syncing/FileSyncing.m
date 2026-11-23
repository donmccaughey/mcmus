#import "FileSyncing.h"
#import "FileSyncingClient.h"

@implementation FileSyncing {
    FileSyncingClient *_client;
}

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(nullable id<FileSyncingDelegate>)delegate
                      fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _client = [[FileSyncingClient alloc] initWithMusicDir:musicDir
                                               workingDir:workingDir
                                             manifestPath:manifestPath
                                                 delegate:delegate
                                               fileSystem:fileSystem];

    return self;
}

- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)start;
{
    dispatch_async(_client.queue, ^{ [self->_client start]; });
}

@end
