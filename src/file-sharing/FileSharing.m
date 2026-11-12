#import "FileSharing.h"

#if TARGET_OS_OSX


#import "FileSharingThread.h"
#import "FileSystemReal.h"


static NSErrorDomain const FileSharingErrorDomain = @"FileSharingErrorDomain";

typedef NS_ENUM(NSInteger, FileSharingErrorCode) {
    FileSharingErrorCodeNoMusicRootDirectory = 1,
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


@implementation FileSharing {
    NSURL *_Nullable _musicRootDirectoryURL;
    id<FileSystem> _fileSystem;
    id<FileSharingService> _Nullable _service;
}


+ (NSNotificationName)didChangeNotification;
{
    return @"FileSharingDidChange";
}


- (instancetype)initWithMusicRootDirectoryURL:
                    (nullable NSURL *)musicRootDirectoryURL
                                   fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _musicRootDirectoryURL = musicRootDirectoryURL;
    _fileSystem = fileSystem;

    return self;
}


- (instancetype)initWithMusicRootDirectoryURL:
    (nullable NSURL *)musicRootDirectoryURL;
{
    return [self initWithMusicRootDirectoryURL:musicRootDirectoryURL
                                    fileSystem:[[FileSystemReal alloc] init]];
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
    _service = [[FileSharingThread alloc] initWithFileSystem:_fileSystem];
    [_service startSharingMusicDirectory:_musicRootDirectoryURL reply:reply];
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
    [NSNotificationCenter.defaultCenter
        postNotificationName:FileSharing.didChangeNotification
                      object:self];
}


@end


#endif
