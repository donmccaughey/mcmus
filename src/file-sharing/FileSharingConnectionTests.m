#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "FileSharingConnection.h"
#import "HTTPRequestParser.h"
#import "NetworkFake.h"


static NSString *const header = @"HTTP/1.1 200 OK\r\n\r\n";


static NSData *utf8(NSString *text)
{
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}


static NSString *get(NSString *path)
{
    return [NSString stringWithFormat:@"GET %@ HTTP/1.1\r\n\r\n", path];
}


@interface ConnectionDelegateFake : NSObject <FileSharingConnectionDelegate>

@property (nonatomic, readonly) NSMutableArray<NSString *> *events;
@property (nonatomic, copy) void (^onRequest)
    (FileSharingConnection *connection, HTTPRequest *request);

@end


@implementation ConnectionDelegateFake


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _events = [NSMutableArray new];

    return self;
}


- (void)connectionDidBeginRequest:(FileSharingConnection *)connection;
{
    [_events addObject:@"begin"];
}


- (void)connection:(FileSharingConnection *)connection
    didReceiveRequest:(nullable HTTPRequest *)request;
{
    [_events addObject:request.path];
    _onRequest(connection, request);
}


- (void)connectionDidEndRequest:(FileSharingConnection *)connection;
{
    [_events addObject:@"end"];
}


- (void)connectionDidClose:(FileSharingConnection *)connection;
{
    [_events addObject:@"close"];
}


@end


@interface FileSharingConnectionTests : XCTestCase
@end


@implementation FileSharingConnectionTests {
    ClockFake *_clock;
    ConnectionDelegateFake *_delegate;
    NetworkConnectionFake *_client;
    FileSharingConnection *_connection;
    NSUInteger _countOfPartsAskedFor;
}


- (void)setUp;
{
    [super setUp];
    NetworkFake *network = [NetworkFake new];
    id<NetworkListener> listener = [network listenAndReturnError:NULL];
    listener.onConnection = ^(id<NetworkConnection> accepted) {};
    _client = [network connectFrom:@"192.168.1.20"];
    _clock = [ClockFake new];
    _delegate = [ConnectionDelegateFake new];
    _connection = [[FileSharingConnection alloc] initWithConnection:_client
                                                              clock:_clock
                                                  isOverClientLimit:NO
                                                           delegate:_delegate];
}


- (ResponseBodySource)bodySourceOf:(NSArray<NSString *> *)parts;
{
    NSEnumerator<NSString *> *remainingParts = parts.objectEnumerator;
    return ^NSData *_Nullable
    {
        ++self->_countOfPartsAskedFor;
        NSString *part = remainingParts.nextObject;
        return part ? utf8(part) : nil;
    };
}


- (void)answerRequestsWithBody:(NSArray<NSString *> *)parts
                    bodyLength:(unsigned long long)bodyLength
                       closing:(BOOL)closesConnection;
{
    __weak typeof(self) weakSelf = self;
    _delegate.onRequest =
        ^(FileSharingConnection *connection, HTTPRequest *request) {
            [connection respondWithHeader:utf8(header)
                               bodyLength:bodyLength
                                     body:[weakSelf bodySourceOf:parts]
                                  closing:closesConnection];
        };
}


- (void)testSendsHeaderThenBodyPartsInOrder;
{
    [self answerRequestsWithBody:@[@"one,", @"two,", @"three"]
                      bodyLength:13
                         closing:NO];

    [_client receive:get(@"/files")];

    XCTAssertEqualObjects(
        _client.sentText, [header stringByAppendingString:@"one,two,three"]
    );
    XCTAssertEqual(_countOfPartsAskedFor, 3UL);
    XCTAssertFalse(_client.isClosed);
}


- (void)testRequestEndsAfterTheLastBodyPart;
{
    [self answerRequestsWithBody:@[@"one,", @"two"] bodyLength:7 closing:NO];

    [_client receive:get(@"/files")];

    XCTAssertEqualObjects(_delegate.events, (@[@"begin", @"/files", @"end"]));
    XCTAssertFalse(_connection.hasActiveRequest);
}


- (void)testClosingResponseClosesAfterTheLastBodyPart;
{
    [self answerRequestsWithBody:@[@"one,", @"two"] bodyLength:7 closing:YES];

    [_client receive:get(@"/files")];

    XCTAssertEqualObjects(
        _client.sentText, [header stringByAppendingString:@"one,two"]
    );
    XCTAssertTrue(_client.isClosed);
    XCTAssertEqualObjects(_delegate.events, (@[@"begin", @"/files", @"close"]));
}


- (void)testResponseWithoutBodyIsOnlyTheHeader;
{
    _delegate.onRequest =
        ^(FileSharingConnection *connection, HTTPRequest *request) {
            [connection respond:utf8(header) closing:NO];
        };

    [_client receive:get(@"/manifest")];

    XCTAssertEqualObjects(_client.sentText, header);
    XCTAssertEqualObjects(
        _delegate.events, (@[@"begin", @"/manifest", @"end"])
    );
}


// Sends that complete at once must not nest a call for each part: this many
// nested calls would overflow the stack.
- (void)testBodyOfManyPartsIsSentWithoutNesting;
{
    NSUInteger partCount = 200000;
    NSMutableArray<NSString *> *parts = [NSMutableArray new];
    for (NSUInteger i = 0; i < partCount; ++i)
        [parts addObject:@"x"];
    [self answerRequestsWithBody:parts bodyLength:partCount closing:NO];

    [_client receive:get(@"/files")];

    XCTAssertEqual(_client.sentData.length, header.length + partCount);
    XCTAssertFalse(_connection.hasActiveRequest);
}


- (void)testNextBodyPartIsNotAskedForUntilThePartBeforeItIsSent;
{
    [self answerRequestsWithBody:@[@"one,", @"two"] bodyLength:7 closing:NO];
    _client.isStalled = YES;

    [_client receive:get(@"/files")];

    XCTAssertEqual(_countOfPartsAskedFor, 0UL);
    XCTAssertTrue(_connection.hasActiveRequest);

    [_client finishSending];

    XCTAssertEqualObjects(
        _client.sentText, [header stringByAppendingString:@"one,two"]
    );
    XCTAssertFalse(_connection.hasActiveRequest);
}


- (void)testClosesWhenTheBodyMakesNoProgressForTenSeconds;
{
    [self answerRequestsWithBody:@[@"one,", @"two"] bodyLength:7 closing:NO];
    _client.isStalled = YES;
    [_client receive:get(@"/files")];

    [_clock advance:9.9];
    XCTAssertFalse(_client.isClosed);

    [_clock advance:0.1];
    XCTAssertTrue(_client.isClosed);
    XCTAssertFalse(_connection.hasActiveRequest);
}


- (void)testClosesWhenTheBodySourceEndsEarly;
{
    [self answerRequestsWithBody:@[@"one,"] bodyLength:7 closing:NO];

    [_client receive:get(@"/files")];

    XCTAssertEqualObjects(
        _client.sentText, [header stringByAppendingString:@"one,"]
    );
    XCTAssertTrue(_client.isClosed);
    XCTAssertEqualObjects(_delegate.events, (@[@"begin", @"/files", @"close"]));
}


- (void)testClosesWhenTheBodySourceReturnsAnEmptyPart;
{
    [self answerRequestsWithBody:@[@"one,", @"", @"two"]
                      bodyLength:7
                         closing:NO];

    [_client receive:get(@"/files")];

    XCTAssertEqualObjects(
        _client.sentText, [header stringByAppendingString:@"one,"]
    );
    XCTAssertTrue(_client.isClosed);
}


- (void)testClosesWithoutSendingAPartLongerThanTheRemainingBody;
{
    [self answerRequestsWithBody:@[@"one,", @"two,three"]
                      bodyLength:7
                         closing:NO];

    [_client receive:get(@"/files")];

    XCTAssertEqualObjects(
        _client.sentText, [header stringByAppendingString:@"one,"]
    );
    XCTAssertTrue(_client.isClosed);
}


- (void)testClosingReleasesTheBodySource;
{
    __weak NSObject *weakOwnedByBodySource = nil;
    @autoreleasepool {
        NSObject *ownedByBodySource = [NSObject new];
        weakOwnedByBodySource = ownedByBodySource;
        _delegate.onRequest =
            ^(FileSharingConnection *connection, HTTPRequest *request) {
                [connection respondWithHeader:utf8(header)
                                   bodyLength:3
                                         body:^NSData *_Nullable {
                                             [ownedByBodySource self];
                                             return utf8(@"one");
                                         }
                                      closing:NO];
            };
        _client.isStalled = YES;
        [_client receive:get(@"/files")];
        _delegate.onRequest =
            ^(FileSharingConnection *connection, HTTPRequest *request) {};
    }
    XCTAssertNotNil(weakOwnedByBodySource);

    [_client closeByClient];

    XCTAssertNil(weakOwnedByBodySource);
    XCTAssertEqualObjects(_delegate.events, (@[@"begin", @"/files", @"close"]));
}


- (void)testRequestReceivedDuringTheBodyIsAnsweredAfterIt;
{
    [self answerRequestsWithBody:@[@"one,", @"two"] bodyLength:7 closing:NO];
    _client.isStalled = YES;
    [_client receive:get(@"/first")];

    [_client receive:get(@"/second")];
    XCTAssertEqualObjects(_delegate.events, (@[@"begin", @"/first"]));

    [_client finishSending];

    NSString *response = [header stringByAppendingString:@"one,two"];
    XCTAssertEqualObjects(
        _client.sentText, [response stringByAppendingString:response]
    );
    XCTAssertEqualObjects(
        _delegate.events, (@[@"begin", @"/first", @"/second", @"end"])
    );
}


@end


#endif
