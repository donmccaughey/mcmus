#import "FileSyncing.h"

#import "Browser.h"
#import "BrowserDelegate.h"
#import "FileSyncingDelegate.h"
#import "Resolver.h"
#import "ResolverDelegate.h"


@interface FileSyncing () <BrowserDelegate, ResolverDelegate>
@end


@implementation FileSyncing {
    __weak id<FileSyncingDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    dispatch_queue_t _serialQueue;
    id<DNS> _dns;
    id<Clock> _clock;

    // objects below live on _serialQueue
    Browser *_browser;
    Resolver *_resolver;
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

    _serialQueue = dispatch_queue_create(
        NSStringFromClass(self.class).UTF8String, DISPATCH_QUEUE_SERIAL
    );

    return self;
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
                                                          dns:self->_dns];
        [self->_resolver start];
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
