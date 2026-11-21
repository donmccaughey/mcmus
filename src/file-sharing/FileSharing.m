#import "FileSharing.h"

#if TARGET_OS_OSX


#import "FileSharingThread.h"


static NSErrorDomain const FileSharingErrorDomain = @"FileSharingErrorDomain";

typedef NS_ENUM(NSInteger, FileSharingErrorCode) {
    FileSharingErrorCodeNoMusicRootDirectory = 1,
    FileSharingErrorCodeNoWorkingDirectory = 2,
};


static NSError *no_music_root_directory_error(void)
{
    return [NSError
        errorWithDomain:FileSharingErrorDomain
                   code:FileSharingErrorCodeNoMusicRootDirectory
               userInfo:@{
                   NSLocalizedDescriptionKey: @"No music root directory.",
               }];
}


static NSError *no_working_directory_error(void)
{
    return
        [NSError errorWithDomain:FileSharingErrorDomain
                            code:FileSharingErrorCodeNoWorkingDirectory
                        userInfo:@{
                            NSLocalizedDescriptionKey: @"No working directory.",
                        }];
}


@interface FileSharing () <FileSharingClient>
@end


@implementation FileSharing {
    NSURL *_Nullable _musicRootDirectoryURL;
    NSURL *_Nullable _workingDirectoryURL;
    id<FileSystem> _fileSystem;
    id<Network> _network;
    id<Clock> _clock;
    id<FileSharingService> _Nullable _service;
}


+ (NSNotificationName)didChangeNotification;
{
    return @"FileSharingDidChange";
}


- (instancetype)
    initWithMusicRootDirectoryURL:(nullable NSURL *)musicRootDirectoryURL
              workingDirectoryURL:(nullable NSURL *)workingDirectoryURL
                       fileSystem:(id<FileSystem>)fileSystem
                          network:(id<Network>)network
                            clock:(id<Clock>)clock;
{
    self = [super init];
    if (!self) return nil;

    _musicRootDirectoryURL = musicRootDirectoryURL;
    _workingDirectoryURL = workingDirectoryURL;
    _fileSystem = fileSystem;
    _network = network;
    _clock = clock;

    return self;
}


- (BOOL)isSharing;
{
    return FileSharingStateSharing == _state;
}


- (BOOL)isChanging;
{
    return FileSharingStateStarting == _state
        || FileSharingStateStopping == _state;
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
    [self didChangeState:FileSharingStateStarting port:0 error:nil];

    void (^reply)(uint16_t, NSError *_Nullable) =
        ^(uint16_t port, NSError *_Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) self->_service = nil;
                [self didChangeState:(error ? FileSharingStateOff
                                            : FileSharingStateSharing)
                                port:port
                               error:error];
                if (completion) completion();
            });
        };

    if (!_musicRootDirectoryURL) {
        reply(0, no_music_root_directory_error());
        return;
    }
    if (!_workingDirectoryURL) {
        reply(0, no_working_directory_error());
        return;
    }
    _service = [[FileSharingThread alloc] initWithFileSystem:_fileSystem
                                                     network:_network
                                                       clock:_clock
                                                      client:self];
    [_service startSharingMusicDirectory:_musicRootDirectoryURL
                        workingDirectory:_workingDirectoryURL
                                   reply:reply];
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
    [self didChangeState:FileSharingStateStopping port:0 error:nil];

    [_service stopSharingWithReply:^(NSError *_Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_service = nil;
            [self didChangeState:FileSharingStateOff port:0 error:error];
            if (completion) completion();
        });
    }];
}


- (void)didChangeState:(FileSharingState)state
                  port:(uint16_t)port
                 error:(nullable NSError *)error;
{
    _state = state;
    _port = port;
    _error = error;
    _metadataTracksLoaded = 0;
    _metadataTotalTracks = 0;
    _connectedDeviceName = nil;
    [self postDidChange];
}


- (void)postDidChange;
{
    [NSNotificationCenter.defaultCenter
        postNotificationName:FileSharing.didChangeNotification
                      object:self];
}


#pragma mark - FileSharingClient, called on any thread


- (void)didLoadMetadataForTracks:(NSUInteger)tracksLoaded
                         ofTotal:(NSUInteger)totalTracks;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (FileSharingStateStarting != self->_state) return;
        self->_metadataTracksLoaded = tracksLoaded;
        self->_metadataTotalTracks = totalTracks;
        [self postDidChange];
    });
}


- (void)serverIsWaitingForClient;
{
    [self serverDidChangeClient:nil];
}


- (void)serverDidConnectClient:(NSString *)deviceName;
{
    [self serverDidChangeClient:deviceName];
}


// The server reports the client again each time the client resumes after a
// pause, so reports that change nothing are not passed on.
- (void)serverDidChangeClient:(nullable NSString *)deviceName;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (FileSharingStateSharing != self->_state) return;
        BOOL isUnchanged = deviceName == self->_connectedDeviceName ||
            [deviceName isEqual:self->_connectedDeviceName];
        if (isUnchanged) return;
        self->_connectedDeviceName = [deviceName copy];
        [self postDidChange];
    });
}


@end


#endif
