#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "DNSFake.h"
#import "FileShare.h"
#import "NSError+FileSyncing.h"
#import "Resolver.h"
#import "ResolverDelegate.h"


static char const *const DelegateQueueLabel = "ResolverTests delegate";
static NSTimeInterval const Timeout = 5;


static NSString *current_queue_label(void)
{
    return @(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
}


@interface ResolverDelegateSpy : NSObject <ResolverDelegate>

@property (nonatomic, readonly) NSMutableArray<FileShare *> *fileShares;
@property (nonatomic, readonly) NSMutableArray<NSURL *> *urls;
@property (nonatomic, readonly) NSMutableArray<NSError *> *errors;
@property (nonatomic, readonly) NSMutableArray<NSString *> *queueLabels;

@end


@implementation ResolverDelegateSpy


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _fileShares = [NSMutableArray new];
    _urls = [NSMutableArray new];
    _errors = [NSMutableArray new];
    _queueLabels = [NSMutableArray new];

    return self;
}


- (void)didResolveFileShare:(FileShare *)fileShare withURL:(NSURL *)url;
{
    [_fileShares addObject:fileShare];
    [_urls addObject:url];
    [_queueLabels addObject:current_queue_label()];
}


- (void)didFailToResolveFileShare:(FileShare *)fileShare
                        withError:(NSError *)error;
{
    [_fileShares addObject:fileShare];
    [_errors addObject:error];
    [_queueLabels addObject:current_queue_label()];
}


@end


@interface ResolverTests : XCTestCase
@end


@implementation ResolverTests {
    FileShare *_fileShare;
    dispatch_queue_serial_t _serialQueue;
    dispatch_queue_t _delegateQueue;
    ResolverDelegateSpy *_delegate;
    DNSFake *_dns;
    ClockFake *_clock;
    Resolver *_resolver;
}


- (void)setUp;
{
    [super setUp];
    _fileShare = [[FileShare alloc] initWithInterfaceIndex:4
                                               serviceName:"Den Mac"
                                                   regtype:"_mcmus._tcp."
                                               replyDomain:"local."];
    _serialQueue = (dispatch_queue_serial_t)dispatch_queue_create(
        "ResolverTests serial", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL
    );
    _delegateQueue = dispatch_queue_create(
        DelegateQueueLabel, DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL
    );
    _delegate = [ResolverDelegateSpy new];
    _dns = [DNSFake new];
    _clock = [ClockFake new];
    _resolver = [[Resolver alloc] initWithFileShare:_fileShare
                                        serialQueue:_serialQueue
                                            timeout:Timeout
                                           delegate:_delegate
                                      delegateQueue:_delegateQueue
                                                dns:_dns
                                              clock:_clock];
}


// Resolver asserts that it runs on its serial queue, and reports to its
// delegate asynchronously, so each step runs there and then waits for the
// delegate queue to empty.
- (void)onSerialQueue:(void (^)(void))block;
{
    dispatch_sync(_serialQueue, block);
    dispatch_sync(_delegateQueue, ^{});
}


- (void)start;
{
    Resolver *resolver = _resolver;
    [self onSerialQueue:^{ [resolver start]; }];
}


- (void)resolveToTargetHostname:(char const *)targetHostname
                           port:(uint16_t)port;
{
    DNSResolveFake *resolve = _dns.resolve;
    [self onSerialQueue:^{
        [resolve resolveToTargetHostname:targetHostname port:port];
    }];
}


- (void)failResolveWithErrorCode:(DNSServiceErrorType)errorCode;
{
    DNSResolveFake *resolve = _dns.resolve;
    [self onSerialQueue:^{ [resolve failWithErrorCode:errorCode]; }];
}


- (void)advance:(NSTimeInterval)interval;
{
    ClockFake *clock = _clock;
    [self onSerialQueue:^{ [clock advance:interval]; }];
}


- (void)assertResolvedOnceWithURL:(NSString *)urlString;
{
    XCTAssertEqualObjects(_delegate.fileShares, @[_fileShare]);
    XCTAssertEqualObjects(_delegate.urls, @[[NSURL URLWithString:urlString]]);
    XCTAssertEqualObjects(_delegate.errors, @[]);
}


- (void)assertFailedOnceWithErrorCode:(DNSServiceErrorType)errorCode;
{
    XCTAssertEqualObjects(_delegate.fileShares, @[_fileShare]);
    XCTAssertEqualObjects(_delegate.urls, @[]);
    XCTAssertEqual(_delegate.errors.count, 1UL);
    NSError *error = _delegate.errors.firstObject;
    XCTAssertEqualObjects(error.domain, DNSServiceErrorTypeDomain);
    XCTAssertEqual(error.code, (NSInteger)errorCode);
}


#pragma mark - start tests


- (void)testStartResolvesFileShareOnItsInterface;
{
    [self start];

    DNSResolveFake *resolve = _dns.resolve;
    XCTAssertNotNil(resolve);
    XCTAssertEqual(resolve.flags, (DNSServiceFlags)0);
    XCTAssertEqual(resolve.interfaceIndex, (uint32_t)4);
    XCTAssertEqualObjects(resolve.name, @"Den Mac");
    XCTAssertEqualObjects(resolve.regtype, @"_mcmus._tcp.");
    XCTAssertEqualObjects(resolve.domain, @"local.");
    XCTAssertFalse(resolve.isDeallocated);
}


- (void)testStartDeliversRepliesOnSerialQueue;
{
    [self start];

    XCTAssertEqual(_dns.resolve.dispatchQueue, _serialQueue);
}


- (void)testStartFailsWhenResolveFails;
{
    _dns.resolveError = kDNSServiceErr_BadParam;

    [self start];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_BadParam];
    XCTAssertNil(_dns.resolve);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testStartFailsWhenSettingDispatchQueueFails;
{
    _dns.setDispatchQueueError = kDNSServiceErr_BadReference;

    [self start];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_BadReference];
    XCTAssertTrue(_dns.resolve.isDeallocated);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


#pragma mark - resolve reply tests


- (void)testReplyReportsURLWithoutTrailingDotInHost;
{
    [self start];

    [self resolveToTargetHostname:"den-mac.local." port:8080];

    [self assertResolvedOnceWithURL:@"http://den-mac.local:8080"];
}


- (void)testReplyReportsURLForHostWithoutTrailingDot;
{
    [self start];

    [self resolveToTargetHostname:"den-mac.local" port:8080];

    [self assertResolvedOnceWithURL:@"http://den-mac.local:8080"];
}


- (void)testReplyStopsResolving;
{
    [self start];

    [self resolveToTargetHostname:"den-mac.local." port:8080];

    XCTAssertTrue(_dns.resolve.isDeallocated);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testReplyErrorFails;
{
    [self start];

    [self failResolveWithErrorCode:kDNSServiceErr_ServiceNotRunning];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_ServiceNotRunning];
    XCTAssertTrue(_dns.resolve.isDeallocated);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testReportsOnDelegateQueue;
{
    [self start];

    [self resolveToTargetHostname:"den-mac.local." port:8080];

    XCTAssertEqualObjects(_delegate.queueLabels, @[@(DelegateQueueLabel)]);
}


#pragma mark - timeout tests


- (void)testReportsNothingBeforeTimeout;
{
    [self start];

    [self advance:Timeout - 0.5];

    XCTAssertEqualObjects(_delegate.fileShares, @[]);
    XCTAssertFalse(_dns.resolve.isDeallocated);
}


- (void)testTimeoutFails;
{
    [self start];

    [self advance:Timeout];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_Timeout];
    XCTAssertTrue(_dns.resolve.isDeallocated);
}


- (void)testTimeoutFailureIsReportedOnDelegateQueue;
{
    [self start];

    [self advance:Timeout];

    XCTAssertEqualObjects(_delegate.queueLabels, @[@(DelegateQueueLabel)]);
}


#pragma mark - lifetime tests


- (void)testResolverKeepsItselfAliveUntilItFinishes;
{
    __weak Resolver *weakResolver = _resolver;
    @autoreleasepool {
        [self start];
        _resolver = nil;
    }
    XCTAssertNotNil(weakResolver);

    @autoreleasepool {
        [self resolveToTargetHostname:"den-mac.local." port:8080];
    }

    XCTAssertNil(weakResolver);
    [self assertResolvedOnceWithURL:@"http://den-mac.local:8080"];
}


- (void)testUnstartedResolverIsReleasedWithItsOwner;
{
    __weak Resolver *weakResolver = _resolver;

    @autoreleasepool {
        _resolver = nil;
    }

    XCTAssertNil(weakResolver);
}


@end
