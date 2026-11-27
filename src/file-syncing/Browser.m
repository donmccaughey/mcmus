#import "Browser.h"

#import "BrowserDelegate.h"
#import "Clock.h"
#import "DNS.h"
#import "FileShare.h"
#import "NSError+FileSyncing.h"


static void browseReply(
    DNSServiceRef serviceRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char *serviceName,
    const char *regtype,
    const char *replyDomain,
    void *context
);


@interface Browser ()

@property (nonatomic, readonly) dispatch_queue_t serialQueue;

- (void)browseWithFlags:(DNSServiceFlags)flags
         interfaceIndex:(uint32_t)interfaceIndex
            serviceName:(char const *)serviceName
                regtype:(char const *)regtype
            replyDomain:(char const *)replyDomain
              errorCode:(DNSServiceErrorType)errorCode;

- (void)cleanup;

- (void)finishWithErrorCode:(DNSServiceErrorType)errorCode;

- (void)finishWithFileShares;

- (void)startBrowsing;

@end


@implementation Browser {
    dispatch_queue_t _serialQueue;
    NSTimeInterval _timeout;
    id<ClockTimer> _Nullable _timeoutTimer;
    __weak id<BrowserDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    NSMutableArray<FileShare *> *_fileShares;
    id<DNS> _dns;
    id<Clock> _clock;
    DNSServiceRef _serviceRef;
}

- (instancetype)initWithSerialQueue:(dispatch_queue_t)serialQueue
                            timeout:(NSTimeInterval)timeout
                           delegate:(id<BrowserDelegate>)delegate
                      delegateQueue:(dispatch_queue_t)delegateQueue
                                dns:(id<DNS>)dns
                              clock:(id<Clock>)clock;
{
    self = [super init];
    if (!self) return nil;

    _serialQueue = serialQueue;
    _timeout = timeout;
    _delegate = delegate;
    _delegateQueue = delegateQueue;
    _dns = dns;
    _clock = clock;

    _fileShares = [NSMutableArray new];

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)browseWithFlags:(DNSServiceFlags)flags
         interfaceIndex:(uint32_t)interfaceIndex
            serviceName:(char const *)serviceName
                regtype:(char const *)regtype
            replyDomain:(char const *)replyDomain
              errorCode:(DNSServiceErrorType)errorCode;
{
    dispatch_assert_queue(_serialQueue);

    if (kDNSServiceErr_NoError != errorCode) {
        if (_fileShares.count) {
            [self finishWithFileShares];
        } else {
            [self finishWithErrorCode:errorCode];
        }
        return;
    }

    FileShare *fileShare =
        [[FileShare alloc] initWithInterfaceIndex:interfaceIndex
                                      serviceName:serviceName
                                          regtype:regtype
                                      replyDomain:replyDomain];
    if (kDNSServiceFlagsAdd & flags) {
        [_fileShares addObject:fileShare];
    } else {
        [_fileShares removeObject:fileShare];
    }
}


- (void)cleanup;
{
    dispatch_assert_queue(_serialQueue);

    [_timeoutTimer cancel];
    _timeoutTimer = nil;

    if (_serviceRef) {
        [_dns deallocateServiceRef:_serviceRef];
        _serviceRef = NULL;
        // balances CFRetain in -start
        CFRelease((__bridge CFTypeRef)self);
    }
}


- (void)finishWithErrorCode:(DNSServiceErrorType)errorCode;
{
    dispatch_assert_queue(_serialQueue);

    __strong id<BrowserDelegate> delegate = _delegate;
    NSError *error = [NSError dnsServiceErrorWithCode:errorCode];
    dispatch_async(_delegateQueue, ^{
        [delegate didFailToBrowseWithError:error];
    });

    [self cleanup];
}


- (void)finishWithFileShares;
{
    dispatch_assert_queue(_serialQueue);

    __strong id<BrowserDelegate> delegate = _delegate;
    __strong NSArray<FileShare *> *fileShares = [_fileShares copy];
    dispatch_async(_delegateQueue, ^{
        [delegate didFindFileShares:fileShares];
    });

    [self cleanup];
}


- (void)start;
{
    dispatch_async(_serialQueue, ^{ [self startBrowsing]; });
}

- (void)startBrowsing;
{
    dispatch_assert_queue(_serialQueue);

    DNSServiceErrorType errorCode;

    DNSServiceFlags flags = 0;
    char const *domain = NULL;
    errorCode = [_dns browse:&_serviceRef
                       flags:flags
              interfaceIndex:kDNSServiceInterfaceIndexAny
                     regtype:"_mcmus._tcp"
                      domain:domain
                    callBack:browseReply
                     context:(__bridge void *)self];
    if (kDNSServiceErr_NoError != errorCode) {
        [self finishWithErrorCode:errorCode];
        return;
    }
    // retain self for the browse callback
    // balances CFRelease in -cleanup
    CFRetain((__bridge CFTypeRef)self);

    errorCode = [_dns setDispatchQueue:_serialQueue forServiceRef:_serviceRef];
    if (kDNSServiceErr_NoError != errorCode) {
        [self finishWithErrorCode:errorCode];
        return;
    }

    __weak Browser *weakSelf = self;
    _timeoutTimer = [_clock after:_timeout
                          onQueue:_serialQueue
                              run:^{ [weakSelf finishWithFileShares]; }];
}


@end


static void browseReply(
    DNSServiceRef serviceRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char *serviceName,
    const char *regtype,
    const char *replyDomain,
    void *context
)
{
    Browser *browser = (__bridge Browser *)context;
    NSCAssert(browser, @"Expected a Browser");
    dispatch_assert_queue(browser.serialQueue);
    [browser browseWithFlags:flags
              interfaceIndex:interfaceIndex
                 serviceName:serviceName
                     regtype:regtype
                 replyDomain:replyDomain
                   errorCode:errorCode];
}
