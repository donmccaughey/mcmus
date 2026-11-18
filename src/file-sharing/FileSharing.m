#import "FileSharing.h"

#if TARGET_OS_OSX


#import "ClockReal.h"
#import "FileSharingThread.h"
#import "FileSystemReal.h"
#import "NetworkReal.h"


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


- (instancetype)
    initWithMusicRootDirectoryURL:(nullable NSURL *)musicRootDirectoryURL
              workingDirectoryURL:(nullable NSURL *)workingDirectoryURL;
{
    return [self initWithMusicRootDirectoryURL:musicRootDirectoryURL
                           workingDirectoryURL:workingDirectoryURL
                                    fileSystem:[FileSystemReal new]
                                       network:[NetworkReal new]
                                         clock:[ClockReal new]];
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
    [self didChangeState:FileSharingStateStarting error:nil];

    void (^reply)(NSError *_Nullable) = ^(NSError *_Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) self->_service = nil;
            [self didChangeState:(error ? FileSharingStateOff
                                        : FileSharingStateSharing)
                           error:error];
            if (completion) completion();
        });
    };

    if (!_musicRootDirectoryURL) {
        reply(no_music_root_directory_error());
        return;
    }
    if (!_workingDirectoryURL) {
        reply(no_working_directory_error());
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
    [self didChangeState:FileSharingStateStopping error:nil];

    [_service stopSharingWithReply:^(NSError *_Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_service = nil;
            [self didChangeState:FileSharingStateOff error:error];
            if (completion) completion();
        });
    }];
}


- (void)didChangeState:(FileSharingState)state error:(nullable NSError *)error;
{
    _state = state;
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
