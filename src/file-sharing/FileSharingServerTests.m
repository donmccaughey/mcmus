#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "FileSharingServer.h"
#import "NetworkFake.h"


static NSString *const iPhoneAddress = @"192.168.1.20";
static NSString *const iPadAddress = @"192.168.1.30";

static NSString *const manifest =
    @"path,size,hash\r\nArtist/Album/Song.mp3,5,7\r\n";


static NSString *request(NSString *method, NSString *path, NSString *userAgent)
{
    return [NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\n"
                                      @"Host: mac.local\r\n"
                                      @"User-Agent: %@\r\n"
                                      @"\r\n",
        method, path, userAgent];
}


static NSString *get_manifest(NSString *userAgent)
{
    return request(@"GET", @"/manifest", userAgent);
}


static NSUInteger count_of(NSString *part, NSString *text)
{
    return [text componentsSeparatedByString:part].count - 1;
}


@interface FileSharingServerTests : XCTestCase
@end


@implementation FileSharingServerTests {
    NetworkFake *_network;
    ClockFake *_clock;
    FileSharingServer *_server;
    NSMutableArray<NSString *> *_events;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _network = [NetworkFake new];
    _clock = [ClockFake new];
    _server = [[FileSharingServer alloc]
        initWithNetwork:_network
                  clock:_clock
               manifest:[manifest dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableArray<NSString *> *events = [NSMutableArray new];
    _events = events;
    _server.onWaitingForClient = ^{ [events addObject:@"waiting"]; };
    _server.onClientConnected = ^(NSString *deviceName) {
        [events addObject:[@"connected: " stringByAppendingString:deviceName]];
    };
}


- (void)start;
{
    NSError *error = nil;
    XCTAssertTrue([_server startAndReturnError:&error], @"%@", error);
    [_events removeAllObjects];
}


- (NetworkConnectionFake *)connectAndGetManifestFrom:(NSString *)address;
{
    NetworkConnectionFake *connection = [_network connectFrom:address];
    [connection receive:get_manifest(@"iPhone")];
    return connection;
}


// Leaves the server in the client connected state with one request active.
- (NetworkConnectionFake *)connectWithStalledResponse;
{
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    connection.isStalled = YES;
    [connection receive:get_manifest(@"iPhone")];
    return connection;
}


- (void)assertRejected:(NetworkConnectionFake *)connection
            statusLine:(NSString *)statusLine
                  body:(NSString *)body;
{
    NSString *response = connection.sentText;
    XCTAssertTrue([response hasPrefix:statusLine], @"%@", response);
    XCTAssertTrue(
        [response containsString:@"Content-Type: text/plain;charset=UTF-8\r\n"],
        @"%@", response);
    XCTAssertTrue(
        [response containsString:@"Connection: close\r\n"], @"%@", response);
    NSString *end = [@"\r\n\r\n" stringByAppendingString:body];
    XCTAssertTrue([response hasSuffix:end], @"%@", response);
    XCTAssertTrue(connection.isClosed);
}


#pragma mark - start and stop


- (void)testStartAdvertisesTheListenerPort;
{
    _network.port = 51234;

    [self start];

    XCTAssertNotNil(_network.listener);
    XCTAssertEqualObjects(_network.advertisement.type, @"_mcmus._tcp");
    XCTAssertEqual(_network.advertisement.port, 51234);
}


- (void)testStartNotifiesWaitingForClient;
{
    XCTAssertTrue([_server startAndReturnError:NULL]);

    XCTAssertEqualObjects(_events, @[@"waiting"]);
    XCTAssertEqual(_server.state, FileSharingServerStateWaitingForClient);
}


- (void)testStartFailsWhenListeningFails;
{
    _network.listenError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:EADDRINUSE
                                           userInfo:nil];

    NSError *error = nil;
    BOOL started = [_server startAndReturnError:&error];

    XCTAssertFalse(started);
    XCTAssertEqualObjects(error, _network.listenError);
    XCTAssertNil(_network.advertisement);
    XCTAssertEqualObjects(_events, @[]);
}


- (void)testStartFailsAndStopsListeningWhenAdvertisingFails;
{
    _network.advertiseError = [NSError errorWithDomain:@"TestErrorDomain"
                                                  code:1
                                              userInfo:nil];

    NSError *error = nil;
    BOOL started = [_server startAndReturnError:&error];

    XCTAssertFalse(started);
    XCTAssertEqualObjects(error, _network.advertiseError);
    XCTAssertTrue(_network.listener.isClosed);
    XCTAssertEqualObjects(_events, @[]);
}


- (void)testStopClosesListenerAdvertisementAndConnections;
{
    [self start];
    NetworkConnectionFake *idle = [_network connectFrom:iPhoneAddress];
    NetworkConnectionFake *active = [self connectWithStalledResponse];
    [_events removeAllObjects];

    [_server stop];

    XCTAssertTrue(_network.listener.isClosed);
    XCTAssertTrue(_network.advertisement.isClosed);
    XCTAssertTrue(idle.isClosed);
    XCTAssertTrue(active.isClosed);
    XCTAssertEqualObjects(_events, @[]);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


#pragma mark - get manifest


- (void)testGetManifestRespondsWithManifestCSV;
{
    [self start];

    NetworkConnectionFake *connection =
        [self connectAndGetManifestFrom:iPhoneAddress];

    NSString *response = connection.sentText;
    XCTAssertTrue([response hasPrefix:@"HTTP/1.1 200 OK\r\n"], @"%@", response);
    XCTAssertTrue(
        [response containsString:@"Content-Type: text/csv;charset=UTF-8\r\n"],
        @"%@", response);
    XCTAssertTrue(
        [response containsString:@"Content-Length: 43\r\n"], @"%@", response);
    XCTAssertFalse([response containsString:@"Connection: close"]);
    NSString *end = [@"\r\n\r\n" stringByAppendingString:manifest];
    XCTAssertTrue([response hasSuffix:end], @"%@", response);
    XCTAssertFalse(connection.isClosed);
}


- (void)testConnectionServesOneRequestAfterAnother;
{
    [self start];
    NetworkConnectionFake *connection =
        [self connectAndGetManifestFrom:iPhoneAddress];

    [connection receive:get_manifest(@"iPhone")];

    XCTAssertEqual(count_of(@"HTTP/1.1 200 OK\r\n", connection.sentText), 2UL);
    XCTAssertFalse(connection.isClosed);
}


- (void)testRequestsReceivedTogetherAreEachServed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:[get_manifest(@"iPhone")
                            stringByAppendingString:get_manifest(@"iPhone")]];

    XCTAssertEqual(count_of(@"HTTP/1.1 200 OK\r\n", connection.sentText), 2UL);
    XCTAssertEqualObjects(_events, @[@"connected: iPhone"]);
}


- (void)testRequestReceivedDuringAResponseIsServedAfterIt;
{
    [self start];
    NetworkConnectionFake *connection = [self connectWithStalledResponse];

    [connection receive:get_manifest(@"iPhone")];
    XCTAssertEqual(connection.sentData.length, 0UL);
    [connection finishSending];

    XCTAssertEqual(count_of(@"HTTP/1.1 200 OK\r\n", connection.sentText), 2UL);
}


- (void)testRequestSplitAcrossReadsIsServed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:@"GET /manifest HTTP/1.1\r\nUser-"];
    XCTAssertEqual(connection.sentData.length, 0UL);
    [connection receive:@"Agent: iPhone\r\n\r\n"];

    XCTAssertTrue([connection.sentText hasPrefix:@"HTTP/1.1 200 OK\r\n"]);
}


- (void)testConnectionCloseRequestClosesAfterResponse;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:@"GET /manifest HTTP/1.1\r\n"
                        @"User-Agent: iPhone\r\n"
                        @"Connection: close\r\n"
                        @"\r\n"];

    XCTAssertTrue([connection.sentText hasPrefix:@"HTTP/1.1 200 OK\r\n"]);
    XCTAssertTrue([connection.sentText containsString:@"Connection: close"]);
    XCTAssertTrue(connection.isClosed);
}


- (void)testUnknownPathIsNotFound;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:request(@"GET", @"/tracks", @"iPhone")];

    NSString *response = connection.sentText;
    XCTAssertTrue(
        [response hasPrefix:@"HTTP/1.1 404 Not Found\r\n"], @"%@", response);
    XCTAssertTrue([response hasSuffix:@"\r\n\r\nNot found"], @"%@", response);
    XCTAssertFalse(connection.isClosed);
}


- (void)testOtherMethodOnManifestIsNotAllowed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:request(@"DELETE", @"/manifest", @"iPhone")];

    NSString *response = connection.sentText;
    XCTAssertTrue([response hasPrefix:@"HTTP/1.1 405 Method Not Allowed\r\n"],
        @"%@", response);
    XCTAssertFalse(connection.isClosed);
}


#pragma mark - client states


- (void)testFirstCompleteRequestConnectsClientNamedByUserAgent;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    connection.isStalled = YES;

    [connection receive:@"GET /manifest HTTP/1.1\r\n"];
    XCTAssertEqual(_server.state, FileSharingServerStateWaitingForClient);
    XCTAssertEqualObjects(_events, @[]);

    [connection receive:@"User-Agent: Don's iPhone\r\n\r\n"];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);
    XCTAssertEqualObjects(_events, @[@"connected: Don's iPhone"]);
}


- (void)testDeviceNameIsLimitedToSixtyFourCharacters;
{
    [self start];
    NSString *longName = [@"" stringByPaddingToLength:100
                                           withString:@"iPhone "
                                      startingAtIndex:0];

    [[_network connectFrom:iPhoneAddress] receive:get_manifest(longName)];

    NSString *deviceName =
        [_events.firstObject substringFromIndex:@"connected: ".length];
    XCTAssertEqual(deviceName.length, 64UL);
    XCTAssertTrue([longName hasPrefix:deviceName]);
}


- (void)testClientLingersWhenItsLastResponseIsSent;
{
    [self start];
    NetworkConnectionFake *connection = [self connectWithStalledResponse];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);

    [connection finishSending];

    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
    XCTAssertEqualObjects(_events, @[@"connected: iPhone"]);
}


- (void)testClientStaysConnectedWhileAnotherRequestIsActive;
{
    [self start];
    NetworkConnectionFake *first = [self connectWithStalledResponse];
    NetworkConnectionFake *second = [self connectWithStalledResponse];

    [first finishSending];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);

    [second finishSending];
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


- (void)testClientLingersWhenConnectionWithItsLastActiveRequestCloses;
{
    [self start];
    NetworkConnectionFake *connection = [self connectWithStalledResponse];

    [connection closeByClient];

    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


- (void)testLingeringClientTimesOutAfterFiveSeconds;
{
    [self start];
    [self connectAndGetManifestFrom:iPhoneAddress];
    [_events removeAllObjects];

    [_clock advance:4.9];
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
    XCTAssertEqualObjects(_events, @[]);

    [_clock advance:0.1];
    XCTAssertEqual(_server.state, FileSharingServerStateWaitingForClient);
    XCTAssertEqualObjects(_events, @[@"waiting"]);
}


- (void)testClientTimeoutClosesItsIdleConnections;
{
    [self start];
    NetworkConnectionFake *connection =
        [self connectAndGetManifestFrom:iPhoneAddress];

    [_clock advance:5];

    XCTAssertTrue(connection.isClosed);
}


- (void)testNewRequestWhileLingeringReconnectsClientAndCancelsTimeout;
{
    [self start];
    NetworkConnectionFake *connection =
        [self connectAndGetManifestFrom:iPhoneAddress];
    [_clock advance:3];
    [_events removeAllObjects];

    [connection receive:@"GET /manifest HTTP/1.1\r\n"];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);
    XCTAssertEqualObjects(_events, @[@"connected: iPhone"]);

    [_clock advance:5];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);
}


- (void)testAnotherClientCanConnectAfterTheFirstTimesOut;
{
    [self start];
    [self connectAndGetManifestFrom:iPhoneAddress];
    [_clock advance:5];
    [_events removeAllObjects];

    NetworkConnectionFake *connection = [_network connectFrom:iPadAddress];
    [connection receive:get_manifest(@"iPad")];

    XCTAssertTrue([connection.sentText hasPrefix:@"HTTP/1.1 200 OK\r\n"]);
    XCTAssertEqualObjects(_events, @[@"connected: iPad"]);
}


#pragma mark - rejected requests


- (void)testRequestFromAnotherClientWhileConnectedIsUnavailable;
{
    [self start];
    [self connectWithStalledResponse];
    [_events removeAllObjects];

    NetworkConnectionFake *other = [_network connectFrom:iPadAddress];
    [other receive:get_manifest(@"iPad")];

    [self assertRejected:other
              statusLine:@"HTTP/1.1 503 Service Unavailable\r\n"
                    body:@"Max clients connected"];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);
    XCTAssertEqualObjects(_events, @[]);
}


- (void)testRequestFromAnotherClientWhileLingeringIsUnavailable;
{
    [self start];
    [self connectAndGetManifestFrom:iPhoneAddress];

    NetworkConnectionFake *other = [_network connectFrom:iPadAddress];
    [other receive:get_manifest(@"iPad")];

    [self assertRejected:other
              statusLine:@"HTTP/1.1 503 Service Unavailable\r\n"
                    body:@"Max clients connected"];
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


- (void)testRequestWithoutUserAgentIsBadRequest;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:@"GET /manifest HTTP/1.1\r\nHost: mac.local\r\n\r\n"];

    [self assertRejected:connection
              statusLine:@"HTTP/1.1 400 Bad Request\r\n"
                    body:@"Missing User-Agent header"];
    XCTAssertEqual(_server.state, FileSharingServerStateWaitingForClient);
    XCTAssertEqualObjects(_events, @[]);
}


- (void)testUnparsableRequestIsBadRequest;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:@"hello there\r\n\r\n"];

    [self assertRejected:connection
              statusLine:@"HTTP/1.1 400 Bad Request\r\n"
                    body:@"Invalid request"];
    XCTAssertEqual(_server.state, FileSharingServerStateWaitingForClient);
}


- (void)testSeventhConnectionFromClientIsTooManyRequests;
{
    [self start];
    NSMutableArray<NetworkConnectionFake *> *allowed = [NSMutableArray new];
    for (int i = 0; i < 6; ++i) {
        [allowed addObject:[self connectAndGetManifestFrom:iPhoneAddress]];
    }

    NetworkConnectionFake *seventh = [_network connectFrom:iPhoneAddress];
    [seventh receive:get_manifest(@"iPhone")];

    [self assertRejected:seventh
              statusLine:@"HTTP/1.1 429 Too Many Requests\r\n"
                    body:@"Too many connections"];
    for (NetworkConnectionFake *connection in allowed) {
        XCTAssertTrue([connection.sentText hasPrefix:@"HTTP/1.1 200 OK\r\n"]);
        XCTAssertFalse(connection.isClosed);
    }
}


- (void)testSeventhConnectionDoesNotKeepClientConnected;
{
    [self start];
    for (int i = 0; i < 6; ++i) {
        [self connectAndGetManifestFrom:iPhoneAddress];
    }
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);

    NetworkConnectionFake *seventh = [_network connectFrom:iPhoneAddress];
    [seventh receive:@"GET /manifest HTTP/1.1\r\n"];

    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


- (void)testClientCanConnectAgainAfterClosingOneOfSixConnections;
{
    [self start];
    NetworkConnectionFake *first =
        [self connectAndGetManifestFrom:iPhoneAddress];
    for (int i = 0; i < 5; ++i) {
        [self connectAndGetManifestFrom:iPhoneAddress];
    }

    [first closeByClient];
    NetworkConnectionFake *next =
        [self connectAndGetManifestFrom:iPhoneAddress];

    XCTAssertTrue([next.sentText hasPrefix:@"HTTP/1.1 200 OK\r\n"]);
}


- (void)testSeventeenthOpenConnectionIsClosedAtOnce;
{
    [self start];
    NSMutableArray<NetworkConnectionFake *> *open = [NSMutableArray new];
    for (int i = 0; i < 16; ++i) {
        NSString *address =
            [NSString stringWithFormat:@"192.168.1.%d", 100 + i];
        [open addObject:[_network connectFrom:address]];
    }

    NetworkConnectionFake *seventeenth = [_network connectFrom:iPhoneAddress];

    XCTAssertTrue(seventeenth.isClosed);
    XCTAssertEqual(seventeenth.sentData.length, 0UL);
    XCTAssertFalse(open.lastObject.isClosed);
}


#pragma mark - timeouts


- (void)testConnectionIdleForTenSecondsIsClosed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [_clock advance:9.9];
    XCTAssertFalse(connection.isClosed);

    [_clock advance:0.1];
    XCTAssertTrue(connection.isClosed);
    XCTAssertEqual(connection.sentData.length, 0UL);
}


// A second connection holds a request open so that the client does not time
// out, which would close the idle connection early.
- (void)testConnectionIdleForTenSecondsAfterAResponseIsClosed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    [_clock advance:6];
    [connection receive:get_manifest(@"iPhone")];
    [_clock advance:4];
    [[_network connectFrom:iPhoneAddress]
        receive:@"GET /manifest HTTP/1.1\r\n"];

    [_clock advance:5.9];
    XCTAssertFalse(connection.isClosed);

    [_clock advance:0.1];
    XCTAssertTrue(connection.isClosed);
}


- (void)testRequestNotFullyReadWithinTenSecondsClosesConnection;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    [_clock advance:5];

    [connection receive:@"GET /manifest HTTP/1.1\r\n"];
    [_clock advance:9];
    [connection receive:@"Host: mac.local\r\n"];
    XCTAssertFalse(connection.isClosed);

    [_clock advance:1];
    XCTAssertTrue(connection.isClosed);
    XCTAssertEqual(connection.sentData.length, 0UL);
}


- (void)testRequestReadTimeoutEndsTheClientsActiveRequest;
{
    [self start];
    [self connectAndGetManifestFrom:iPhoneAddress];
    NetworkConnectionFake *slow = [_network connectFrom:iPhoneAddress];
    [slow receive:@"GET /manifest HTTP/1.1\r\n"];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);

    [_clock advance:10];

    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


- (void)testResponseWithoutProgressForTenSecondsClosesConnection;
{
    [self start];
    NetworkConnectionFake *connection = [self connectWithStalledResponse];

    [_clock advance:9.9];
    XCTAssertFalse(connection.isClosed);

    [_clock advance:0.1];
    XCTAssertTrue(connection.isClosed);
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


@end


#endif
