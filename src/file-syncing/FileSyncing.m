#import "FileSyncing.h"

#import "Browser.h"
#import "BrowserDelegate.h"
#import "FileSyncingDelegate.h"
#import "Manifest.h"
#import "NSError+FileSyncing.h"
#import "NSURL+FileSyncing.h"
#import "Resolver.h"
#import "ResolverDelegate.h"


NSTimeInterval const resolveTimeout = 3.0;


@interface FileSyncing () <
    BrowserDelegate,
    NSURLSessionDelegate,
    NSURLSessionDataDelegate,
    NSURLSessionTaskDelegate,
    ResolverDelegate>

- (void)getManifestFromServerAtURL:(NSURL *)serverURL;

- (void)resolveFileShare:(FileShare *)fileShare
             withTimeout:(NSTimeInterval)timeout;

@end


// A device that has never synced has no manifest file, so every failure to
// load one reads as having no tracks yet.
static Manifest *load_manifest_or_empty(
    NSURL *manifestPath, id<FileSystem> fileSystem
)
{
    return [Manifest newWithCSVPath:manifestPath
                         fileSystem:fileSystem
                              error:NULL]
        ?: [Manifest new];
}


@implementation FileSyncing {
    __weak id<FileSyncingDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    dispatch_queue_t _serialQueue;
    id<DNS> _dns;
    id<Clock> _clock;
    Manifest *_localManifest;
    NSURLSession *_session;

    // Assigned on _serialQueue before -fileSyncing:didGetManifest: is
    // enqueued, so the delegate can read it from that call onwards.
    Manifest *_serverManifest;

    // objects below live on _serialQueue
    Browser *_browser;
    Resolver *_resolver;
    NSURLSessionDataTask *_manifestTask;
    NSMutableData *_manifestData;
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
    _localManifest = load_manifest_or_empty(manifestPath, fileSystem);

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


- (void)dealloc;
{
    [_session finishTasksAndInvalidate];
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)findFileSharesWithTimeout:(NSTimeInterval)timeout;
{
    dispatch_async(_serialQueue, ^{
        NSAssert(!self->_browser, @"Expected only one active Browser");
        self->_browser = [[Browser alloc] initWithSerialQueue:self->_serialQueue
                                                      timeout:timeout
                                                     delegate:self
                                                delegateQueue:self->_serialQueue
                                                          dns:self->_dns
                                                        clock:self->_clock];
        [self->_browser start];
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
    dispatch_async(_serialQueue, ^{
        NSAssert(!self->_resolver, @"Expected only one active Resolver");
        self->_resolver = [[Resolver alloc] initWithFileShare:fileShare
                                                  serialQueue:self->_serialQueue
                                                      timeout:timeout
                                                     delegate:self
                                                delegateQueue:self->_serialQueue
                                                          dns:self->_dns
                                                        clock:self->_clock];
        [self->_resolver start];
    });
}


- (void)syncWithFileShare:(FileShare *)fileShare;
{
    [self resolveFileShare:fileShare withTimeout:resolveTimeout];
}


- (void)didFailToGetManifestWithError:(NSError *)error;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self didFailToGetManifestWithError:error];
    });
}


#pragma BrowserDelegate


- (void)didFindFileShares:(NSArray<FileShare *> *)fileShares;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self didFindFileShares:fileShares];
    });
    _browser = nil;
}


- (void)didFailToBrowseWithError:(NSError *)error;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self
            didFailToFindFileSharesWithError:error];
    });
    _browser = nil;
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

    _serverManifest = manifest;
    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self didGetManifest:manifest];
    });

    // TODO: compare local and server manifest
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
