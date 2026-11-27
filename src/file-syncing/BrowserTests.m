#import <XCTest/XCTest.h>

#import "Browser.h"
#import "BrowserDelegate.h"
#import "ClockFake.h"
#import "DNSFake.h"
#import "FileShare.h"
#import "NSError+FileSyncing.h"


static char const *const DelegateQueueLabel = "BrowserTests delegate";
static NSTimeInterval const Timeout = 5;


static FileShare *file_share(uint32_t interfaceIndex, char const *serviceName)
{
    return [[FileShare alloc] initWithInterfaceIndex:interfaceIndex
                                         serviceName:serviceName
                                             regtype:"_mcmus._tcp."
                                         replyDomain:"local."];
}


static NSString *current_queue_label(void)
{
    return @(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
}


@interface BrowserDelegateSpy : NSObject <BrowserDelegate>

@property (nonatomic, readonly) NSMutableArray<NSArray<FileShare *> *> *found;
@property (nonatomic, readonly) NSMutableArray<NSError *> *errors;
@property (nonatomic, readonly) NSMutableArray<NSString *> *queueLabels;

@end


@implementation BrowserDelegateSpy


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _found = [NSMutableArray new];
    _errors = [NSMutableArray new];
    _queueLabels = [NSMutableArray new];

    return self;
}


- (void)didFindFileShares:(NSArray<FileShare *> *)fileShares;
{
    [_found addObject:fileShares];
    [_queueLabels addObject:current_queue_label()];
}


- (void)didFailToBrowseWithError:(NSError *)error;
{
    [_errors addObject:error];
    [_queueLabels addObject:current_queue_label()];
}


@end


@interface BrowserTests : XCTestCase
@end


@implementation BrowserTests {
    dispatch_queue_t _serialQueue;
    dispatch_queue_t _delegateQueue;
    BrowserDelegateSpy *_delegate;
    DNSFake *_dns;
    ClockFake *_clock;
    Browser *_browser;
}


- (void)setUp;
{
    [super setUp];
    _serialQueue =
        dispatch_queue_create("BrowserTests serial", DISPATCH_QUEUE_SERIAL);
    _delegateQueue =
        dispatch_queue_create(DelegateQueueLabel, DISPATCH_QUEUE_SERIAL);
    _delegate = [BrowserDelegateSpy new];
    _dns = [DNSFake new];
    _clock = [ClockFake new];
    _browser = [[Browser alloc] initWithSerialQueue:_serialQueue
                                            timeout:Timeout
                                           delegate:_delegate
                                      delegateQueue:_delegateQueue
                                                dns:_dns
                                              clock:_clock];
}


// Browser asserts that it runs on its serial queue, and reports to its
// delegate asynchronously, so each step runs there and then waits for the
// delegate queue to empty.
- (void)onSerialQueue:(void (^)(void))block;
{
    dispatch_sync(_serialQueue, block);
    dispatch_sync(_delegateQueue, ^{});
}


- (void)start;
{
    [_browser start];
    [self onSerialQueue:^{}];
}


- (void)add:(char const *)serviceName onInterface:(uint32_t)interfaceIndex;
{
    DNSBrowseFake *browse = _dns.browse;
    [self onSerialQueue:^{
        [browse addServiceName:serviceName
                interfaceIndex:interfaceIndex
                       regtype:"_mcmus._tcp."
                   replyDomain:"local."];
    }];
}


- (void)remove:(char const *)serviceName onInterface:(uint32_t)interfaceIndex;
{
    DNSBrowseFake *browse = _dns.browse;
    [self onSerialQueue:^{
        [browse removeServiceName:serviceName
                   interfaceIndex:interfaceIndex
                          regtype:"_mcmus._tcp."
                      replyDomain:"local."];
    }];
}


- (void)failBrowseWithErrorCode:(DNSServiceErrorType)errorCode;
{
    DNSBrowseFake *browse = _dns.browse;
    [self onSerialQueue:^{ [browse failWithErrorCode:errorCode]; }];
}


- (void)advance:(NSTimeInterval)interval;
{
    ClockFake *clock = _clock;
    [self onSerialQueue:^{ [clock advance:interval]; }];
}


- (void)assertFailedOnceWithErrorCode:(DNSServiceErrorType)errorCode;
{
    XCTAssertEqualObjects(_delegate.found, @[]);
    XCTAssertEqual(_delegate.errors.count, 1UL);
    NSError *error = _delegate.errors.firstObject;
    XCTAssertEqualObjects(error.domain, DNSServiceErrorTypeDomain);
    XCTAssertEqual(error.code, (NSInteger)errorCode);
}


#pragma mark - start tests


- (void)testStartBrowsesForFileSharesOnEveryInterface;
{
    [self start];

    DNSBrowseFake *browse = _dns.browse;
    XCTAssertNotNil(browse);
    XCTAssertEqual(browse.flags, (DNSServiceFlags)0);
    XCTAssertEqual(browse.interfaceIndex, kDNSServiceInterfaceIndexAny);
    XCTAssertEqualObjects(browse.regtype, @"_mcmus._tcp");
    XCTAssertNil(browse.domain);
    XCTAssertFalse(browse.isDeallocated);
}


- (void)testStartDeliversRepliesOnSerialQueue;
{
    [self start];

    XCTAssertEqual(_dns.browse.dispatchQueue, _serialQueue);
}


- (void)testStartFailsWhenBrowseFails;
{
    _dns.browseError = kDNSServiceErr_BadParam;

    [self start];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_BadParam];
    XCTAssertNil(_dns.browse);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testStartFailsWhenSettingDispatchQueueFails;
{
    _dns.setDispatchQueueError = kDNSServiceErr_BadReference;

    [self start];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_BadReference];
    XCTAssertTrue(_dns.browse.isDeallocated);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


#pragma mark - timeout tests


- (void)testReportsNothingBeforeTimeout;
{
    [self start];
    [self add:"Den Mac" onInterface:4];

    [self advance:Timeout - 0.5];

    XCTAssertEqualObjects(_delegate.found, @[]);
    XCTAssertEqualObjects(_delegate.errors, @[]);
    XCTAssertFalse(_dns.browse.isDeallocated);
}


- (void)testTimeoutReportsFileSharesInTheOrderFound;
{
    [self start];
    [self add:"Den Mac" onInterface:4];
    [self add:"Office Mac" onInterface:4];

    [self advance:Timeout];

    NSArray<FileShare *> *expected =
        @[file_share(4, "Den Mac"), file_share(4, "Office Mac")];
    XCTAssertEqualObjects(_delegate.found, @[expected]);
    XCTAssertEqualObjects(_delegate.errors, @[]);
}


- (void)testTimeoutWithoutFileSharesReportsNone;
{
    [self start];

    [self advance:Timeout];

    XCTAssertEqualObjects(_delegate.found, @[@[]]);
    XCTAssertEqualObjects(_delegate.errors, @[]);
}


- (void)testTimeoutStopsBrowsing;
{
    [self start];

    [self advance:Timeout];

    XCTAssertTrue(_dns.browse.isDeallocated);
}


- (void)testReportsOnDelegateQueue;
{
    [self start];

    [self advance:Timeout];

    XCTAssertEqualObjects(_delegate.queueLabels, @[@(DelegateQueueLabel)]);
}


#pragma mark - browse reply tests


- (void)testRemovedFileShareIsNotReported;
{
    [self start];
    [self add:"Den Mac" onInterface:4];
    [self add:"Office Mac" onInterface:4];

    [self remove:"Den Mac" onInterface:4];
    [self advance:Timeout];

    NSArray<FileShare *> *expected = @[file_share(4, "Office Mac")];
    XCTAssertEqualObjects(_delegate.found, @[expected]);
}


- (void)testFileShareIsReportedOncePerInterface;
{
    [self start];

    [self add:"Den Mac" onInterface:4];
    [self add:"Den Mac" onInterface:7];
    [self advance:Timeout];

    NSArray<FileShare *> *expected =
        @[file_share(4, "Den Mac"), file_share(7, "Den Mac")];
    XCTAssertEqualObjects(_delegate.found, @[expected]);
}


- (void)testFileShareRemovedFromOneInterfaceIsReportedOnTheOther;
{
    [self start];
    [self add:"Den Mac" onInterface:4];
    [self add:"Den Mac" onInterface:7];

    [self remove:"Den Mac" onInterface:4];
    [self advance:Timeout];

    NSArray<FileShare *> *expected = @[file_share(7, "Den Mac")];
    XCTAssertEqualObjects(_delegate.found, @[expected]);
}


- (void)testReplyErrorWithoutFileSharesFails;
{
    [self start];

    [self failBrowseWithErrorCode:kDNSServiceErr_ServiceNotRunning];

    [self assertFailedOnceWithErrorCode:kDNSServiceErr_ServiceNotRunning];
    XCTAssertTrue(_dns.browse.isDeallocated);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testReplyErrorAfterFindingFileSharesReportsThem;
{
    [self start];
    [self add:"Den Mac" onInterface:4];

    [self failBrowseWithErrorCode:kDNSServiceErr_ServiceNotRunning];

    NSArray<FileShare *> *expected = @[file_share(4, "Den Mac")];
    XCTAssertEqualObjects(_delegate.found, @[expected]);
    XCTAssertEqualObjects(_delegate.errors, @[]);
    XCTAssertTrue(_dns.browse.isDeallocated);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


#pragma mark - lifetime tests


- (void)testBrowserKeepsItselfAliveUntilItFinishes;
{
    __weak Browser *weakBrowser = _browser;
    @autoreleasepool {
        [self start];
        _browser = nil;
    }
    XCTAssertNotNil(weakBrowser);

    @autoreleasepool {
        [self advance:Timeout];
    }

    XCTAssertNil(weakBrowser);
    XCTAssertEqualObjects(_delegate.found, @[@[]]);
}


- (void)testUnstartedBrowserIsReleasedWithItsOwner;
{
    __weak Browser *weakBrowser = _browser;

    @autoreleasepool {
        _browser = nil;
    }

    XCTAssertNil(weakBrowser);
}


@end
