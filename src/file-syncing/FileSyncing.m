#import "FileSyncing.h"

#import "FileSyncingDelegate.h"
#import "Resolver.h"
#import "ResolverDelegate.h"


@interface FileSyncing () <ResolverDelegate>
@end


@implementation FileSyncing {
    __weak id<FileSyncingDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    dispatch_queue_t _serialQueue;

    Resolver *_resolver; // lives on _serialQueue
}


- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(id<FileSyncingDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                      fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _delegate = delegate;
    _delegateQueue = delegateQueue;

    _serialQueue =
        dispatch_queue_create(self.className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)findFileSharesWithCallback:(find_file_shares_callback)callback
                           onQueue:(dispatch_queue_t)callbackQueue
                     withinSeconds:(NSUInteger)timeoutSeconds;
{
    NSAssert(
        timeoutSeconds < INT_MAX, @"Expected timeoutSeconds less than INT_MAX"
    );
    dispatch_async(_serialQueue, ^{
        find_file_shares(
            self->_serialQueue, callback, callbackQueue, (int)timeoutSeconds
        );
    });
}


- (void)resolveFileShare:(FileShare *)fileShare
             withTimeout:(NSTimeInterval)timeout;
{
    dispatch_async(_serialQueue, ^{
        NSAssert(!self->_resolver, @"Expected only one active Resolver");
        self->_resolver =
            [[Resolver alloc] initWithFileShare:fileShare
                                    serialQueue:self->_serialQueue
                                        timeout:timeout
                                       delegate:self
                                  delegateQueue:self->_serialQueue];
        [self->_resolver start];
    });
}


#pragma ResolverDelegate


- (void)didResolveFileShare:(FileShare *)fileShare withURL:(NSURL *)url;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate fileSyncing:self
                 didResolveFileShare:fileShare
                             withURL:url];
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
