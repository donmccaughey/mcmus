#import "FileSyncing.h"

#import "FileSyncingDelegate.h"
#import "FileSyncingState.h"
#import "Manifest.h"
#import "NSError+FileSyncing.h"
#import "NSURL+FileSyncing.h"
#import "Resolver.h"
#import "ResolverDelegate.h"


// these delegates run on _serialQueue
@interface FileSyncing () <
    NSURLSessionDelegate,
    NSURLSessionDataDelegate,
    NSURLSessionTaskDelegate,
    ResolverDelegate>
@end


// these methods run on _serialQueue
@interface FileSyncing (Internal)

- (void)didFailToGetManifestWithError:(NSError *)error;

- (void)getManifestFromServerAtURL:(NSURL *)serverURL;

- (void)resolveFileShare:(FileShare *)fileShare
             withTimeout:(NSTimeInterval)timeout;

@end


@implementation FileSyncing {
    __weak id<FileSyncingDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    dispatch_queue_t _serialQueue;
    id<DNS> _dns;
    id<Clock> _clock;
    NSURLSession *_session;

    // objects below live on _serialQueue
    Resolver *_resolver;
    NSURLSessionDataTask *_manifestTask;
    NSMutableData *_manifestData;
    FileSyncingState *_state;
}


- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(id<FileSyncingDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                      fileSystem:(id<FileSystem>)fileSystem
                             dns:(id<DNS>)dns
                           clock:(id<Clock>)clock;
{
    self = [super init];
    if (!self) return nil;

    _delegate = delegate;
    _delegateQueue = delegateQueue;
    _dns = dns;
    _clock = clock;
    _state = [[FileSyncingState alloc] initWithLocalManifestPath:manifestPath
                                                   andFileSystem:fileSystem];

    _serialQueue = dispatch_queue_create(
        NSStringFromClass(self.class).UTF8String, DISPATCH_QUEUE_SERIAL
    );

    NSOperationQueue *serialOperationQueue = [NSOperationQueue new];
    serialOperationQueue.underlyingQueue = _serialQueue;
    NSString *identifier = NSStringFromClass([self class]);
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
        backgroundSessionConfigurationWithIdentifier:identifier];
    _session = [NSURLSession sessionWithConfiguration:configuration
                                             delegate:self
                                        delegateQueue:serialOperationQueue];

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)dealloc;
{
    [_session finishTasksAndInvalidate];
}


- (Manifest *)localManifest;
{
    return _state.localManifest;
}


- (nullable Manifest *)serverManifest;
{
    return _state.serverManifest;
}


- (void)syncWithFileShare:(FileShare *)fileShare;
{
    // TODO: validate local manifest against music dir
    dispatch_async(_serialQueue, ^{
        [self resolveFileShare:fileShare withTimeout:3.0];
    });
}


#pragma Internal


- (void)didFailToGetManifestWithError:(NSError *)error;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self didFailToGetManifestWithError:error];
    });
}


- (void)getManifestFromServerAtURL:(NSURL *)serverURL;
{
    dispatch_assert_queue(_serialQueue);

    NSAssert(!_manifestTask, @"Expected only one active manifest request");

    _manifestData = [NSMutableData new];
    _manifestTask = [_session dataTaskWithURL:serverURL.manifestURL];
    [_manifestTask resume];
}


- (void)resolveFileShare:(FileShare *)fileShare
             withTimeout:(NSTimeInterval)timeout;
{
    dispatch_assert_queue(_serialQueue);

    NSAssert(!self->_resolver, @"Expected only one active Resolver");
    self->_resolver = [[Resolver alloc] initWithFileShare:fileShare
                                              serialQueue:self->_serialQueue
                                                  timeout:timeout
                                                 delegate:self
                                            delegateQueue:self->_serialQueue
                                                      dns:self->_dns
                                                    clock:self->_clock];
    [self->_resolver start];
}


#pragma NSURLSessionDelegate


- (void)URLSession:(NSURLSession *)session
    didBecomeInvalidWithError:(NSError *)error;
{
    dispatch_assert_queue(_serialQueue);

    // TODO: determine how to handle this
    NSLog(@"URL session failed: %@", error);
}


#pragma NSURLSessionDataDelegate


- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data;
{
    dispatch_assert_queue(_serialQueue);

    NSAssert(_manifestData, @"Expected _manifestData");
    [_manifestData appendData:data];
}


#pragma NSURLSessionTaskDelegate


- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error;
{
    dispatch_assert_queue(_serialQueue);

    // TODO: also handle `/files` tasks

    _manifestTask = nil;
    if (error) {
        [self didFailToGetManifestWithError:error];
        return;
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
    if (200 != httpResponse.statusCode) {
        NSError *httpError = [NSError httpStatusErrorForResponse:httpResponse];
        [self didFailToGetManifestWithError:httpError];
        return;
    }

    NSError *parseError;
    Manifest *manifest = [[Manifest alloc] initWithCSV:_manifestData
                                                 error:&parseError];
    if (!manifest) {
        [self didFailToGetManifestWithError:parseError];
        return;
    }

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self didGetManifest:manifest];
    });

    [_state updateWithServerManifest:manifest];

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self
            willSyncWithModifiedTrackCount:self->_state.modifiedTrackCount];
    });
    // TODO: remove old tracks, download new & updated tracks
    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self
            didSyncWithModifiedTrackCount:self->_state.modifiedTrackCount];
    });
}


#pragma ResolverDelegate


- (void)didResolveFileShare:(FileShare *)fileShare withURL:(NSURL *)url;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self
                 didResolveFileShare:fileShare
                               toURL:url];
    });
    _resolver = nil;

    [self getManifestFromServerAtURL:url];
}


- (void)didFailToResolveFileShare:(FileShare *)fileShare
                        withError:(NSError *)error;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self
            didFailToResolveFileShare:fileShare
                            withError:error];
    });
    _resolver = nil;
}


@end
