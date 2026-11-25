#import "Resolver.h"

#import "FileShare.h"
#import "NSError+FileSyncing.h"
#import "ResolverDelegate.h"


static void resolveReply(
    DNSServiceRef serviceRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char *fullServiceDomainName,
    const char *targetHostname,
    uint16_t portInNetworkByteOrder,
    uint16_t txtRecordLen,
    const unsigned char *txtRecord,
    void *context
);


@interface Resolver ()

- (void)cleanup;

- (void)finishWithErrorCode:(DNSServiceErrorType)errorCode;

- (void)finishWithURL:(NSURL *)url;

- (void)resolveWithTargetHostname:(char const *)targetHostname
           portInNetworkByteOrder:(uint16_t)portInNetworkByteOrder
                        errorCode:(DNSServiceErrorType)errorCode;

@end


@implementation Resolver {
    FileShare *_fileShare;
    dispatch_queue_t _serialQueue;
    NSTimeInterval _timeout;
    dispatch_block_t _timeoutBlock;
    __weak id<ResolverDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    DNSServiceRef _serviceRef;
}


- (instancetype)initWithFileShare:(FileShare *)fileShare
                      serialQueue:(dispatch_queue_t)serialQueue
                          timeout:(NSTimeInterval)timeout
                         delegate:(id<ResolverDelegate>)delegate
                    delegateQueue:(dispatch_queue_t)delegateQueue;
{
    self = [super init];
    if (!self) return nil;

    _fileShare = fileShare;
    _serialQueue = serialQueue;
    _timeout = timeout;

    dispatch_block_flags_t block_flags = 0;
    __weak Resolver *weakSelf = self;
    _timeoutBlock = dispatch_block_create(block_flags, ^{
        [weakSelf finishWithErrorCode:kDNSServiceErr_Timeout];
    });
    NSAssert(_timeoutBlock, @"Expected to create timeout_block");

    _delegate = delegate;
    _delegateQueue = delegateQueue;

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)cleanup;
{
    dispatch_assert_queue(_serialQueue);

    NSAssert(_timeoutBlock, @"Expected _timeoutBlock");
    dispatch_block_cancel(_timeoutBlock);
    _timeoutBlock = nil;

    if (_serviceRef) {
        DNSServiceRefDeallocate(_serviceRef);
        _serviceRef = NULL;
        CFRelease((__bridge CFTypeRef)self
        ); // balances __bridge_retained in -start
    }
}


- (void)finishWithErrorCode:(DNSServiceErrorType)errorCode;
{
    dispatch_assert_queue(_serialQueue);

    NSError *error = [NSError dnsServiceErrorWithCode:errorCode];
    dispatch_async(_delegateQueue, ^{
        [self->_delegate didFailToResolveFileShare:self->_fileShare
                                         withError:error];
    });

    [self cleanup];
}


- (void)finishWithURL:(NSURL *)url;
{
    dispatch_assert_queue(_serialQueue);

    dispatch_async(_delegateQueue, ^{
        [self->_delegate didResolveFileShare:self->_fileShare withURL:url];
    });

    [self cleanup];
}


- (void)resolveWithTargetHostname:(char const *)targetHostname
           portInNetworkByteOrder:(uint16_t)portInNetworkByteOrder
                        errorCode:(DNSServiceErrorType)errorCode;
{
    dispatch_assert_queue(_serialQueue);

    if (kDNSServiceErr_NoError != errorCode) {
        [self finishWithErrorCode:errorCode];
        return;
    }

    NSString *host = [NSString stringWithCString:targetHostname
                                        encoding:NSUTF8StringEncoding];
    NSAssert(host, @"Expected targetHostname to be UTF-8");

    if ([host hasSuffix:@"."]) {
        NSUInteger last_index = host.length - 1;
        host = [host substringToIndex:last_index];
    }

    NSURLComponents *components = [NSURLComponents new];
    components.scheme = @"http";
    components.host = host;
    components.port =
        [NSNumber numberWithUnsignedShort:ntohs(portInNetworkByteOrder)];

    [self finishWithURL:components.URL];
    return;
}


- (void)start;
{
    dispatch_assert_queue(_serialQueue);

    DNSServiceErrorType errorCode;

    DNSServiceFlags flags = 0;
    errorCode = DNSServiceResolve(
        &_serviceRef,
        flags,
        (uint32_t)_fileShare.interfaceIndex,
        _fileShare.serviceName.UTF8String,
        _fileShare.serviceType.UTF8String,
        _fileShare.domain.UTF8String,
        resolveReply,
        (__bridge_retained void *)self // DNSServiceResolve() retains self
    );
    if (kDNSServiceErr_NoError != errorCode) {
        [self finishWithErrorCode:errorCode];
        return;
    }

    errorCode = DNSServiceSetDispatchQueue(_serviceRef, _serialQueue);
    if (kDNSServiceErr_NoError != errorCode) {
        [self finishWithErrorCode:errorCode];
        return;
    }

    dispatch_time_t timeoutNanos =
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * NSEC_PER_SEC));
    NSAssert(_timeoutBlock, @"Expected _timeoutBlock");
    dispatch_after(timeoutNanos, _serialQueue, _timeoutBlock);
}


@end


static void resolveReply(
    DNSServiceRef serviceRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char *fullServiceDomainName,
    const char *targetHostname,
    uint16_t portInNetworkByteOrder,
    uint16_t txtRecordLen,
    const unsigned char *txtRecord,
    void *context
)
{
    Resolver *resolver = (__bridge Resolver *)context;
    [resolver resolveWithTargetHostname:targetHostname
                 portInNetworkByteOrder:portInNetworkByteOrder
                              errorCode:errorCode];
}
