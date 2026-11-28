#import <XCTest/XCTest.h>

#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#import "NetworkReal.h"


static int connect_ipv4_client(uint16_t port)
{
    struct sockaddr_in address = {
        .sin_len = sizeof address,
        .sin_family = AF_INET,
        .sin_port = htons(port),
    };
    inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (connect(fd, (struct sockaddr *)&address, sizeof address) == 0) {
        return fd;
    }
    close(fd);
    return -1;
}


static int connect_ipv6_client(uint16_t port)
{
    struct sockaddr_in6 address = {
        .sin6_len = sizeof address,
        .sin6_family = AF_INET6,
        .sin6_port = htons(port),
        .sin6_addr = in6addr_loopback,
    };
    int fd = socket(AF_INET6, SOCK_STREAM, 0);
    if (connect(fd, (struct sockaddr *)&address, sizeof address) == 0) {
        return fd;
    }
    close(fd);
    return -1;
}


static NSData *read_bytes(int fd, NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    NSUInteger offset = 0;
    while (offset < length) {
        ssize_t count =
            read(fd, (uint8_t *)data.mutableBytes + offset, length - offset);
        if (count <= 0) break;
        offset += count;
    }
    data.length = offset;
    return data;
}


@interface NetworkRealTests : XCTestCase
@end


@implementation NetworkRealTests {
    NetworkReal *_network;
    id<NetworkListener> _listener;
    id<NetworkConnection> _connection;
    int _client;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _network = [NetworkReal new];
    _client = -1;

    NSError *error = nil;
    _listener = [_network listenAndReturnError:&error];
    XCTAssertNotNil(_listener, @"%@", error);
}


- (void)tearDown;
{
    if (_client != -1) close(_client);
    [_connection close];
    [_listener close];
    [super tearDown];
}


- (void)acceptClient:(int)client;
{
    XCTAssertNotEqual(client, -1);
    _client = client;
    XCTestExpectation *connected =
        [self expectationWithDescription:@"connected"];
    __block id<NetworkConnection> accepted = nil;
    _listener.onConnection = ^(id<NetworkConnection> connection) {
        accepted = connection;
        [connected fulfill];
    };
    [self waitForExpectations:@[connected] timeout:5];
    _connection = accepted;
}


- (void)testListenerChoosesAPort;
{
    XCTAssertNotEqual(_listener.port, 0);
}


- (void)testIPv4ClientIsReportedByItsIPv4Address;
{
    [self acceptClient:connect_ipv4_client(_listener.port)];

    XCTAssertEqualObjects(_connection.clientAddress, @"127.0.0.1");
}


- (void)testIPv6ClientIsReportedByItsIPv6Address;
{
    [self acceptClient:connect_ipv6_client(_listener.port)];

    XCTAssertEqualObjects(_connection.clientAddress, @"::1");
}


- (void)testConnectionReceivesDataFromClient;
{
    [self acceptClient:connect_ipv4_client(_listener.port)];
    XCTestExpectation *received = [self expectationWithDescription:@"received"];
    NSMutableData *data = [NSMutableData new];
    _connection.onData = ^(NSData *chunk) {
        [data appendData:chunk];
        if (data.length == 5) [received fulfill];
    };

    write(_client, "hello", 5);
    [self waitForExpectations:@[received] timeout:5];

    XCTAssertEqualObjects(
        data, [@"hello" dataUsingEncoding:NSUTF8StringEncoding]
    );
}


// Larger than the socket buffers, so the send needs more than one pass.
- (void)testSendDeliversAllDataThenRunsCompletion;
{
    [self acceptClient:connect_ipv4_client(_listener.port)];
    NSMutableData *sent = [NSMutableData dataWithLength:4 * 1024 * 1024];
    memset_pattern4(sent.mutableBytes, "mus!", sent.length);
    XCTestExpectation *completed =
        [self expectationWithDescription:@"completed"];
    XCTestExpectation *read = [self expectationWithDescription:@"read"];
    __block NSUInteger bytesSent = 0;
    _connection.onBytesSent = ^(NSUInteger count) { bytesSent += count; };

    __block NSData *received = nil;
    int client = _client;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        received = read_bytes(client, sent.length);
        [read fulfill];
    });
    [_connection send:sent completion:^{ [completed fulfill]; }];
    [self waitForExpectations:@[completed, read] timeout:10];

    XCTAssertEqualObjects(received, sent);
    XCTAssertEqual(bytesSent, sent.length);
}


- (void)testClientCloseRunsOnClosed;
{
    [self acceptClient:connect_ipv4_client(_listener.port)];
    XCTestExpectation *closed = [self expectationWithDescription:@"closed"];
    _connection.onClosed = ^{ [closed fulfill]; };

    close(_client);
    _client = -1;

    [self waitForExpectations:@[closed] timeout:5];
}


- (void)testCloseDisconnectsClient;
{
    [self acceptClient:connect_ipv4_client(_listener.port)];

    [_connection close];

    XCTAssertEqual(read_bytes(_client, 1).length, 0UL);
}


- (void)testClosedListenerRefusesConnections;
{
    uint16_t port = _listener.port;

    [_listener close];

    XCTAssertEqual(connect_ipv4_client(port), -1);
}


- (void)testAdvertisesService;
{
    NSError *error = nil;
    id<NetworkAdvertisement> advertisement =
        [_network advertiseServiceOfType:@"_mcmus-test._tcp"
                                    port:_listener.port
                                   error:&error];

    XCTAssertNotNil(advertisement, @"%@", error);
    [advertisement close];
}


- (void)testAdvertisementReportsItsRegisteredName;
{
    id<NetworkAdvertisement> advertisement =
        [_network advertiseServiceOfType:@"_mcmus-test._tcp"
                                    port:_listener.port
                                   error:NULL];
    XCTestExpectation *registered =
        [self expectationWithDescription:@"registered"];
    __block NSString *registeredName = nil;
    advertisement.onRegistered = ^(NSString *name) {
        registeredName = name;
        [registered fulfill];
    };

    [self waitForExpectations:@[registered] timeout:5];

    XCTAssertGreaterThan(registeredName.length, 0UL);
    [advertisement close];
}


@end
