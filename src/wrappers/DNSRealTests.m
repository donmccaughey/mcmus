#import <XCTest/XCTest.h>

#import "DNSReal.h"


static void ignoreBrowseReply(
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
}


static void ignoreResolveReply(
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
}


@interface DNSRealTests : XCTestCase
@end


@implementation DNSRealTests {
    DNSReal *_dns;
    DNSServiceRef _serviceRef;
}


- (void)setUp;
{
    _dns = [DNSReal new];
    _serviceRef = NULL;
}


- (void)tearDown;
{
    if (_serviceRef) [_dns deallocateServiceRef:_serviceRef];
}


- (void)testBrowseStartsAndAcceptsDispatchQueue;
{
    DNSServiceErrorType errorCode = [_dns browse:&_serviceRef
                                           flags:0
                                  interfaceIndex:kDNSServiceInterfaceIndexAny
                                         regtype:"_mcmus._tcp"
                                          domain:NULL
                                        callBack:ignoreBrowseReply
                                         context:NULL];

    XCTAssertEqual(errorCode, kDNSServiceErr_NoError);
    XCTAssertTrue(_serviceRef != NULL);
    if (!_serviceRef) return;

    dispatch_queue_t queue = dispatch_queue_create(
        "DNSRealTests", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL
    );
    errorCode = [_dns setDispatchQueue:queue forServiceRef:_serviceRef];

    XCTAssertEqual(errorCode, kDNSServiceErr_NoError);
}


- (void)testResolveStarts;
{
    DNSServiceErrorType errorCode = [_dns resolve:&_serviceRef
                                            flags:0
                                   interfaceIndex:kDNSServiceInterfaceIndexAny
                                             name:"DNSRealTests no such share"
                                          regtype:"_mcmus._tcp"
                                           domain:"local."
                                         callBack:ignoreResolveReply
                                          context:NULL];

    XCTAssertEqual(errorCode, kDNSServiceErr_NoError);
    XCTAssertTrue(_serviceRef != NULL);
}


@end
