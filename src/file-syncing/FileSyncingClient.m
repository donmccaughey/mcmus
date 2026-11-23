#import "FileSyncingClient.h"
#import "FileSyncingDelegate.h"
#import "FileSystem.h"
#import "Manifest.h"

NSString *const FileSyncingID = @"FileSyncing";

static BOOL is_no_such_file_error(NSError *error)
{
    return [error.domain isEqualToString:NSPOSIXErrorDomain]
        && ENOENT == error.code;
}

static Manifest *readManifest(
    NSURL *manifestPath, id<FileSystem> fileSystem, NSError **error)
{
    NSCAssert(error, @"expected non-nil error");
    Manifest *manifest = [Manifest newWithCSVPath:manifestPath
                                       fileSystem:fileSystem
                                            error:error];
    if (manifest) return manifest;
    if (is_no_such_file_error(*error)) return [Manifest new];
    return nil;
}

@implementation FileSyncingClient {
    NSURL *_musicDir;
    NSURL *_workingDir;
    NSURL *_manifestPath;
    id<FileSyncingDelegate> _delegate;
    id<FileSystem> _fileSystem;

    dispatch_queue_t _queue;
    NSOperationQueue *_operationQueue;
    NSURLSession *_session;

    Manifest *_localManifest;
}

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(nullable id<FileSyncingDelegate>)delegate
                      fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _musicDir = musicDir;
    _workingDir = workingDir;
    _manifestPath = manifestPath;
    _delegate = delegate;
    _fileSystem = fileSystem;

    _queue =
        dispatch_queue_create(FileSyncingID.UTF8String, DISPATCH_QUEUE_SERIAL);
    NSOperationQueue *operationQueue = [NSOperationQueue new];
    operationQueue.underlyingQueue = _queue;

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
        backgroundSessionConfigurationWithIdentifier:FileSyncingID];
    _session = [NSURLSession sessionWithConfiguration:configuration
                                             delegate:self
                                        delegateQueue:_operationQueue];

    return self;
}

- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (dispatch_queue_t)queue;
{
    return _queue;
}

- (void)start;
{
    dispatch_async(
        dispatch_get_main_queue(), ^{ [self->_delegate syncDidStart]; });

    NSError *error = nil;
    _localManifest = readManifest(_manifestPath, _fileSystem, &error);
    if (!_localManifest) {
        dispatch_async(dispatch_get_main_queue(),
            ^{ [self->_delegate syncDidFailWithError:error]; });
        return;
    }

    // find server
    // get server manifest
    // calculate diff between local manifest and server manifest
    // remove tracks
    // update and write local manifest
    // create tarball requests

    // save state
    // create download tasks
}

#pragma mark NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
    didBecomeInvalidWithError:(nullable NSError *)error;
{
    dispatch_async(dispatch_get_main_queue(),
        ^{ [self->_delegate syncDidFailWithError:error]; });
    // delete state
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(nullable NSError *)error;
{
    // don't update local manifest
    // update and write state
    // future todo: retries
}

#pragma mark NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location;
{
    // untar file at location to music dir
    // update and write state
    // update and write local manifest
}

@end
