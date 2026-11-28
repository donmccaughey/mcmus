#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "FileSharingServer.h"
#import "FileSystemFake.h"
#import "Manifest.h"
#import "NetworkFake.h"
#import "TarReading.h"
#import "TrackMetadata.h"


static NSString *const iPhoneAddress = @"192.168.1.20";
static NSString *const iPadAddress = @"192.168.1.30";

static NSString *const songPath = @"Artist/Album/Song.mp3";
static NSString *const rosePath =
    @"Piaf, Edith/La Vie en rose (slow chanté).mp3";
static NSString *const bigPath = @"Big/Sixty.mp3";
static NSString *const biggerPath = @"Big/Sixty More.mp3";
static const unsigned long long sixtyMegabytes = 60ULL * 1024 * 1024;

static NSString *const manifest =
    @"path,size,hash\r\n"
    @"Artist/Album/Song.mp3,5,7\r\n"
    @"Big/Sixty More.mp3,62914560,3\r\n"
    @"Big/Sixty.mp3,62914560,2\r\n"
    @"\"Piaf, Edith/La Vie en rose (slow chanté).mp3\",70000,9\r\n";


static NSData *utf8(NSString *text)
{
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}


static NSData *song_contents(void)
{
    return utf8(@"12345");
}


// Longer than the 64 KB buffers a tarball is sent in.
static NSData *rose_contents(void)
{
    NSMutableData *contents = [NSMutableData dataWithLength:70000];
    memset(contents.mutableBytes, 'r', contents.length);
    return contents;
}


static const time_t snapshotTime = 1700000000;


static NSURL *snapshot_directory(void)
{
    return [NSURL fileURLWithPath:@"/snapshot" isDirectory:YES];
}


// The tarball writer opens a track through a file URL, whose path may spell a
// non-ASCII name with different code points than the manifest does. The real
// file system finds the file under either spelling; the fake needs the
// spelling the URL gives.
static NSString *snapshot_file_path(NSString *relativePath)
{
    return [snapshot_directory() URLByAppendingPathComponent:relativePath
                                                 isDirectory:NO]
        .path;
}


static TrackMetadata *make_metadata(
    NSString *relativePath, unsigned long long size, NSUInteger fileHash
)
{
    return [[TrackMetadata alloc] initWithRelativePath:relativePath
                                                  size:size
                                              fileHash:fileHash];
}


static Manifest *make_manifest(void)
{
    return [[Manifest alloc] initWithTrackMetadata:@[
        make_metadata(songPath, 5, 7),
        make_metadata(rosePath, 70000, 9),
        make_metadata(bigPath, sixtyMegabytes, 2),
        make_metadata(biggerPath, sixtyMegabytes, 3),
    ]];
}


static FileSystemFake *make_file_system(void)
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    [fileSystem addPath:snapshot_file_path(songPath) contents:song_contents()];
    [fileSystem addPath:snapshot_file_path(rosePath) contents:rose_contents()];
    return fileSystem;
}


static NSString *request(NSString *method, NSString *path, NSString *userAgent)
{
    return [NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\n"
                                      @"Host: mac.local\r\n"
                                      @"User-Agent: %@\r\n"
                                      @"\r\n",
                                      method,
                                      path,
                                      userAgent];
}


static NSString *get_manifest(NSString *userAgent)
{
    return request(@"GET", @"/manifest", userAgent);
}


static NSString *post_files_with_headers(NSString *headers, NSString *csv)
{
    return [NSString stringWithFormat:@"POST /files HTTP/1.1\r\n"
                                      @"User-Agent: iPhone\r\n"
                                      @"%@"
                                      @"\r\n"
                                      @"%@",
                                      headers,
                                      csv];
}


static NSString *post_files(NSString *csv)
{
    NSString *headers =
        [NSString stringWithFormat:@"Content-Type: text/csv;charset=UTF-8\r\n"
                                   @"Content-Length: %lu\r\n",
                                   utf8(csv).length];
    return post_files_with_headers(headers, csv);
}


static NSString *tarball_csv(NSArray<NSString *> *paths)
{
    NSMutableString *csv = [@"path\r\n" mutableCopy];
    for (NSString *path in paths)
        [csv appendFormat:@"\"%@\"\r\n", path];
    return csv;
}


static NSUInteger length_of_head(NSData *response)
{
    NSRange blankLine = [response rangeOfData:utf8(@"\r\n\r\n")
                                      options:0
                                        range:NSMakeRange(0, response.length)];
    return NSMaxRange(blankLine);
}


// A tarball is not text, so the two parts of its response are split as
// bytes.
static NSString *head_of(NSData *response)
{
    NSData *head =
        [response subdataWithRange:NSMakeRange(0, length_of_head(response))];
    return [[NSString alloc] initWithData:head encoding:NSUTF8StringEncoding];
}


static NSData *body_of(NSData *response)
{
    NSUInteger headLength = length_of_head(response);
    return [response
        subdataWithRange:NSMakeRange(headLength, response.length - headLength)];
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
    FileSystemFake *_fileSystem;
    FileSharingServer *_server;
    NSMutableArray<NSString *> *_events;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _network = [NetworkFake new];
    _clock = [ClockFake new];
    _fileSystem = make_file_system();
    _server = [[FileSharingServer alloc] initWithNetwork:_network
                                                   clock:_clock
                                              fileSystem:_fileSystem
                                                manifest:make_manifest()
                                   musicLibraryDirectory:snapshot_directory()
                                            snapshotTime:snapshotTime];
    NSMutableArray<NSString *> *events = [NSMutableArray new];
    _events = events;
    _server.onAdvertised = ^(NSString *shareName) {
        [events addObject:[@"advertised: " stringByAppendingString:shareName]];
    };
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
        @"%@",
        response
    );
    XCTAssertTrue(
        [response containsString:@"Connection: close\r\n"], @"%@", response
    );
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


- (void)testRegisteredAdvertisementNotifiesAdvertisedWithItsName;
{
    [self start];

    [_network.advertisement registerWithName:@"Den Mac"];

    XCTAssertEqualObjects(_events, @[@"advertised: Den Mac"]);
}


- (void)testPortIsTheListenerPortWhileStarted;
{
    _network.port = 51234;
    XCTAssertEqual(_server.port, 0);

    [self start];
    XCTAssertEqual(_server.port, 51234);

    [_server stop];
    XCTAssertEqual(_server.port, 0);
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
        @"%@",
        response
    );
    NSString *contentLength = [NSString
        stringWithFormat:@"Content-Length: %lu\r\n", utf8(manifest).length];
    XCTAssertTrue([response containsString:contentLength], @"%@", response);
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
        [response hasPrefix:@"HTTP/1.1 404 Not Found\r\n"], @"%@", response
    );
    XCTAssertTrue([response hasSuffix:@"\r\n\r\nNot found"], @"%@", response);
    XCTAssertFalse(connection.isClosed);
}


- (void)testOtherMethodOnManifestIsNotAllowed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:request(@"DELETE", @"/manifest", @"iPhone")];

    NSString *response = connection.sentText;
    XCTAssertTrue(
        [response hasPrefix:@"HTTP/1.1 405 Method Not Allowed\r\n"],
        @"%@",
        response
    );
    XCTAssertFalse(connection.isClosed);
}


#pragma mark - post files


- (NetworkConnectionFake *)connectAndPostFiles:(NSString *)csv;
{
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    [connection receive:post_files(csv)];
    return connection;
}


- (void)assertBadRequest:(NetworkConnectionFake *)connection
                    body:(NSString *)body;
{
    NSString *response = connection.sentText;
    XCTAssertTrue(
        [response hasPrefix:@"HTTP/1.1 400 Bad Request\r\n"], @"%@", response
    );
    XCTAssertTrue(
        [response containsString:@"Content-Type: text/plain;charset=UTF-8\r\n"],
        @"%@",
        response
    );
    NSString *end = [@"\r\n\r\n" stringByAppendingString:body];
    XCTAssertTrue([response hasSuffix:end], @"%@", response);
    XCTAssertFalse(connection.isClosed);
}


- (void)testPostFilesRespondsWithTarballOfTheRequestedTracksInOrder;
{
    [self start];

    NetworkConnectionFake *connection =
        [self connectAndPostFiles:tarball_csv(@[rosePath, songPath])];

    XCTAssertEqualObjects(readTar(body_of(connection.sentData)), (@[
                              @[rosePath, rose_contents()],
                              @[songPath, song_contents()],
                          ]));
    XCTAssertFalse(connection.isClosed);
}


- (void)testPostFilesGivesEveryTarballEntryTheSnapshotTimeAsItsMtime;
{
    [self start];

    NetworkConnectionFake *connection =
        [self connectAndPostFiles:tarball_csv(@[rosePath, songPath])];

    XCTAssertEqualObjects(
        readTarModificationTimes(body_of(connection.sentData)),
        (@[@(snapshotTime), @(snapshotTime)])
    );
}


- (void)testPostFilesRespondsWithTarballHeaders;
{
    [self start];

    NetworkConnectionFake *connection =
        [self connectAndPostFiles:tarball_csv(@[songPath, rosePath])];

    NSString *head = head_of(connection.sentData);
    XCTAssertTrue([head hasPrefix:@"HTTP/1.1 200 OK\r\n"], @"%@", head);
    XCTAssertTrue(
        [head containsString:@"Content-Type: application/x-tar\r\n"],
        @"%@",
        head
    );
    NSString *contentLength =
        [NSString stringWithFormat:@"Content-Length: %lu\r\n",
                                   body_of(connection.sentData).length];
    XCTAssertTrue([head containsString:contentLength], @"%@", head);
    XCTAssertFalse([head containsString:@"Connection: close"]);
}


- (void)testPostFilesConnectsTheClient;
{
    [self start];

    [self connectAndPostFiles:tarball_csv(@[songPath])];

    XCTAssertEqualObjects(_events, @[@"connected: iPhone"]);
}


- (void)testManifestIsServedAfterATarballOnTheSameConnection;
{
    [self start];
    NetworkConnectionFake *connection =
        [self connectAndPostFiles:tarball_csv(@[songPath])];

    [connection receive:get_manifest(@"iPhone")];

    NSString *end = [@"\r\n\r\n" stringByAppendingString:manifest];
    NSData *sent = connection.sentData;
    NSData *sentEnd = [sent
        subdataWithRange:NSMakeRange(
                             sent.length - utf8(end).length, utf8(end).length
                         )];
    XCTAssertEqualObjects(sentEnd, utf8(end));
    XCTAssertFalse(connection.isClosed);
}


- (void)testPostFilesWithConnectionCloseClosesAfterTheTarball;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    NSString *csv = tarball_csv(@[songPath]);
    NSString *headers =
        [NSString stringWithFormat:@"Content-Type: text/csv;charset=UTF-8\r\n"
                                   @"Content-Length: %lu\r\n"
                                   @"Connection: close\r\n",
                                   utf8(csv).length];

    [connection receive:post_files_with_headers(headers, csv)];

    XCTAssertTrue([head_of(connection.sentData)
        containsString:@"Connection: close"]);
    XCTAssertEqualObjects(
        readTar(body_of(connection.sentData)), (@[@[songPath, song_contents()]])
    );
    XCTAssertTrue(connection.isClosed);
}


- (void)testClientLingersOnlyAfterTheLastBytesOfTheTarball;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    connection.isStalled = YES;

    [connection receive:post_files(tarball_csv(@[rosePath]))];
    XCTAssertEqual(_server.state, FileSharingServerStateClientConnected);

    [connection finishSending];
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
    XCTAssertEqualObjects(
        readTar(body_of(connection.sentData)), (@[@[rosePath, rose_contents()]])
    );
}


- (void)testTrackThatCannotBeReadClosesTheConnectionPartWayThroughTheTarball;
{
    _fileSystem.unreadableAfterOpenFiles =
        [NSSet setWithObject:snapshot_file_path(rosePath)];
    [self start];

    NetworkConnectionFake *connection =
        [self connectAndPostFiles:tarball_csv(@[songPath, rosePath])];

    NSString *head = head_of(connection.sentData);
    XCTAssertTrue([head hasPrefix:@"HTTP/1.1 200 OK\r\n"], @"%@", head);
    XCTAssertNil(readTar(body_of(connection.sentData)));
    XCTAssertTrue(connection.isClosed);
    XCTAssertEqual(_server.state, FileSharingServerStateClientLingering);
}


- (void)testOtherMethodOnFilesIsNotAllowed;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:request(@"GET", @"/files", @"iPhone")];

    NSString *response = connection.sentText;
    XCTAssertTrue(
        [response hasPrefix:@"HTTP/1.1 405 Method Not Allowed\r\n"],
        @"%@",
        response
    );
    XCTAssertFalse(connection.isClosed);
}


- (void)testPostFilesWithoutContentLengthIsInvalidContentLength;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];

    [connection receive:post_files_with_headers(
                            @"Content-Type: text/csv;charset=UTF-8\r\n", @""
                        )];

    [self assertBadRequest:connection body:@"Invalid content length"];
}


- (void)testPostFilesWithEmptyBodyIsInvalidContentLength;
{
    [self start];

    NetworkConnectionFake *connection = [self connectAndPostFiles:@""];

    [self assertBadRequest:connection body:@"Invalid content length"];
}


- (void)testPostFilesWithOtherContentTypeIsInvalidContentType;
{
    [self start];
    NetworkConnectionFake *connection = [_network connectFrom:iPhoneAddress];
    NSString *csv = tarball_csv(@[songPath]);
    NSString *headers =
        [NSString stringWithFormat:@"Content-Type: text/plain\r\n"
                                   @"Content-Length: %lu\r\n",
                                   utf8(csv).length];

    [connection receive:post_files_with_headers(headers, csv)];

    [self assertBadRequest:connection body:@"Invalid content type"];
}


- (void)testPostFilesWithOnlyTheHeaderRecordIsInvalidCSV;
{
    [self start];

    NetworkConnectionFake *connection = [self connectAndPostFiles:@"path\r\n"];

    [self assertBadRequest:connection body:@"Invalid CSV"];
}


- (void)testPostFilesWithPathNotInTheManifestIsUnknownTrack;
{
    [self start];

    NetworkConnectionFake *connection = [self
        connectAndPostFiles:tarball_csv(@[songPath, @"Artist/Album/Other.mp3"]
                            )];

    [self assertBadRequest:connection body:@"Unknown track"];
}


- (void)testPostFilesForMoreThanOneHundredMegabytesIsTarballTooBig;
{
    [self start];

    NetworkConnectionFake *connection =
        [self connectAndPostFiles:tarball_csv(@[bigPath, biggerPath])];

    [self assertBadRequest:connection body:@"Tarball too big"];
}


- (void)testTarballIsServedAfterABadRequestOnTheSameConnection;
{
    [self start];
    NetworkConnectionFake *connection = [self connectAndPostFiles:@"path\r\n"];
    NSUInteger badRequestLength = connection.sentData.length;

    [connection receive:post_files(tarball_csv(@[songPath]))];

    NSData *sent = connection.sentData;
    NSData *second = [sent
        subdataWithRange:NSMakeRange(
                             badRequestLength, sent.length - badRequestLength
                         )];
    XCTAssertEqualObjects(
        readTar(body_of(second)), (@[@[songPath, song_contents()]])
    );
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
