#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "FileSharingThread.h"
#import "FileSystemFake.h"
#import "NetworkFake.h"


@interface FileSharingClientFake : NSObject <FileSharingClient>
@property (nonatomic, readonly) NSMutableArray<NSString *> *progress;
@property (nonatomic, readonly) NSMutableArray<NSString *> *serverEvents;
@end


@implementation FileSharingClientFake

- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _progress = [NSMutableArray array];
    _serverEvents = [NSMutableArray array];

    return self;
}

- (void)didLoadMetadataForTracks:(NSUInteger)tracksLoaded
                         ofTotal:(NSUInteger)totalTracks;
{
    [_progress addObject:[NSString stringWithFormat:@"%lu of %lu", tracksLoaded,
                             totalTracks]];
}

- (void)serverIsWaitingForClient;
{
    [_serverEvents addObject:@"waiting"];
}

- (void)serverDidConnectClient:(NSString *)deviceName;
{
    [_serverEvents
        addObject:[@"connected: " stringByAppendingString:deviceName]];
}

@end


@interface FileSharingThreadTests : XCTestCase
@end


@implementation FileSharingThreadTests {
    FileSystemFake *_fileSystem;
    NetworkFake *_network;
    ClockFake *_clock;
    FileSharingClientFake *_client;
    NSURL *_musicDir;
    FileSharingThread *_thread;
    XCTestExpectation *_threadExited;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _fileSystem = [FileSystemFake new];
    _fileSystem.applicationSupportDirectoryURL =
        [NSURL fileURLWithPath:@"/container/AppSupport" isDirectory:YES];
    [_fileSystem addPath:@"/Users/user/Music/Song.mp3"];
    _musicDir = [NSURL fileURLWithPath:@"/Users/user/Music" isDirectory:YES];
    _network = [NetworkFake new];
    _clock = [ClockFake new];
    _client = [FileSharingClientFake new];
    _thread = [[FileSharingThread alloc] initWithFileSystem:_fileSystem
                                                    network:_network
                                                      clock:_clock
                                                     client:_client];
    _threadExited = [[XCTNSNotificationExpectation alloc]
        initWithName:NSThreadWillExitNotification
              object:_thread];
}


- (nullable NSError *)startAndWait;
{
    __block NSError *startError = nil;
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [_thread startSharingMusicDirectory:_musicDir
                                  reply:^(NSError *_Nullable error) {
                                      startError = error;
                                      [started fulfill];
                                  }];
    [self waitForExpectations:@[started] timeout:5];
    return startError;
}


- (nullable NSError *)stopAndWait;
{
    __block NSError *stopError = nil;
    XCTestExpectation *stopped = [self expectationWithDescription:@"stopped"];
    [_thread stopSharingWithReply:^(NSError *_Nullable error) {
        stopError = error;
        [stopped fulfill];
    }];
    [self waitForExpectations:@[stopped] timeout:5];
    return stopError;
}


- (void)testStartTakesSnapshotAndStopRemovesItAndExitsThread;
{
    NSError *startError = [self startAndWait];

    XCTAssertNil(startError);
    XCTAssertTrue(_thread.isExecuting);
    XCTAssertEqualObjects(_fileSystem.clonedSources, @[@"/Users/user/Music"]);
    XCTAssertEqualObjects(
        _fileSystem.clonedDestinations, @[@"/container/AppSupport/snapshot"]);

    NSError *stopError = [self stopAndWait];

    XCTAssertNil(stopError);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testStartReportsMetadataProgressToClientBeforeReplying;
{
    for (int i = 0; i < 250; ++i) {
        [_fileSystem
            addPath:[NSString stringWithFormat:
                            @"/container/AppSupport/snapshot/Song %d.mp3", i]];
    }

    [self startAndWait];

    XCTAssertEqualObjects(_client.progress, (@[@"100 of 250", @"200 of 250"]));

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testStartWithFewTracksReportsNoMetadataProgress;
{
    [self startAndWait];

    XCTAssertEqualObjects(_client.progress, @[]);

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testFailedStartRepliesWithErrorAndExitsThread;
{
    _fileSystem.cloneFileToFileError =
        [NSError errorWithDomain:NSPOSIXErrorDomain code:EXDEV userInfo:nil];

    NSError *startError = [self startAndWait];

    XCTAssertEqualObjects(startError.domain, NSPOSIXErrorDomain);
    XCTAssertEqual(startError.code, EXDEV);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testRemoveFailureIsReportedInStopReply;
{
    [self startAndWait];
    _fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileWriteNoPermissionError
                        userInfo:nil];

    NSError *stopError = [self stopAndWait];

    XCTAssertEqualObjects(stopError.domain, NSCocoaErrorDomain);
    XCTAssertEqual(stopError.code, NSFileWriteNoPermissionError);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (nullable NSString *)writtenManifest;
{
    NSData *manifest =
        _fileSystem.writtenFiles[@"/container/AppSupport/manifest.csv"];
    if (!manifest) return nil;
    return [[NSString alloc] initWithData:manifest
                                 encoding:NSUTF8StringEncoding];
}


- (void)testStartWritesManifestWithRelativePathSizeAndHashOfEachTrack;
{
    [_fileSystem addPath:@"/container/AppSupport/snapshot/Artist"
                    kind:FileSystemFakeKindDirectory];
    [_fileSystem addPath:@"/container/AppSupport/snapshot/Artist/Album"
                    kind:FileSystemFakeKindDirectory];
    [_fileSystem
         addPath:@"/container/AppSupport/snapshot/Artist/Album/Song.mp3"
        contents:[@"0123456789" dataUsingEncoding:NSUTF8StringEncoding]];

    [self startAndWait];

    XCTAssertEqualObjects([self writtenManifest],
        @"path,size,hash\r\n"
        @"Artist/Album/Song.mp3,10,7918246353190764831\r\n");

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testManifestQuotesPathContainingComma;
{
    [_fileSystem addPath:@"/container/AppSupport/snapshot/One, Two.mp3"];

    [self startAndWait];

    XCTAssertEqualObjects([self writtenManifest],
        @"path,size,hash\r\n"
        @"\"One, Two.mp3\",0,3244421341483603138\r\n");

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testManifestOfEmptySnapshotHasOnlyHeader;
{
    [self startAndWait];

    XCTAssertEqualObjects([self writtenManifest], @"path,size,hash\r\n");

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testManifestIsSortedByPathBytes;
{
    for (NSString *name in @[@"b.mp3", @"Z.mp3", @"a.mp3"]) {
        [_fileSystem addPath:[@"/container/AppSupport/snapshot/"
                                 stringByAppendingString:name]];
    }

    [self startAndWait];

    XCTAssertEqualObjects([self writtenManifest],
        @"path,size,hash\r\n"
        @"Z.mp3,0,3244421341483603138\r\n"
        @"a.mp3,0,3244421341483603138\r\n"
        @"b.mp3,0,3244421341483603138\r\n");

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testStopRemovesManifest;
{
    NSString *manifestPath = @"/container/AppSupport/manifest.csv";
    [self startAndWait];
    XCTAssertFalse([_fileSystem.removedPaths containsObject:manifestPath]);

    [self stopAndWait];

    XCTAssertTrue([_fileSystem.removedPaths containsObject:manifestPath]);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


#pragma mark - server tests


// The server belongs to the sharing thread, so the tests reach it there.
- (void)onThread:(void (^)(void))block;
{
    [self performSelector:@selector(run:)
                 onThread:_thread
               withObject:[block copy]
            waitUntilDone:YES];
}


- (void)run:(void (^)(void))block;
{
    block();
}


- (void)testStartStartsServerAndStopStopsIt;
{
    [self startAndWait];

    XCTAssertEqualObjects(_network.advertisement.type, @"_mcmus._tcp");
    XCTAssertFalse(_network.listener.isClosed);
    XCTAssertEqualObjects(_client.serverEvents, @[@"waiting"]);

    [self stopAndWait];

    XCTAssertTrue(_network.listener.isClosed);
    XCTAssertTrue(_network.advertisement.isClosed);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testServerServesTheWrittenManifestAndReportsClientToClient;
{
    [_fileSystem addPath:@"/container/AppSupport/snapshot/One, Two.mp3"];
    [self startAndWait];

    __block NetworkConnectionFake *connection = nil;
    [self onThread:^{
        connection = [self->_network connectFrom:@"192.168.1.20"];
        [connection receive:@"GET /manifest HTTP/1.1\r\n"
                            @"User-Agent: Don's iPhone\r\n"
                            @"\r\n"];
    }];

    NSString *end =
        [@"\r\n\r\n" stringByAppendingString:[self writtenManifest]];
    XCTAssertTrue([connection.sentText hasPrefix:@"HTTP/1.1 200 OK\r\n"]);
    XCTAssertTrue([connection.sentText hasSuffix:end]);
    XCTAssertEqualObjects(
        _client.serverEvents, (@[@"waiting", @"connected: Don's iPhone"]));

    [self onThread:^{ [self->_clock advance:5]; }];

    XCTAssertEqualObjects(_client.serverEvents,
        (@[@"waiting", @"connected: Don's iPhone", @"waiting"]));

    [self stopAndWait];
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testListenFailureFailsStartRemovesManifestAndSnapshotAndExitsThread;
{
    _network.listenError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:EADDRINUSE
                                           userInfo:nil];

    NSError *startError = [self startAndWait];

    XCTAssertEqualObjects(startError, _network.listenError);
    XCTAssertTrue([_fileSystem.removedPaths
        containsObject:@"/container/AppSupport/manifest.csv"]);
    XCTAssertTrue([_fileSystem.removedPaths
        containsObject:@"/container/AppSupport/snapshot"]);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


- (void)testManifestWriteFailureFailsStartAndExitsThread;
{
    _fileSystem.writeDataToFileError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileWriteOutOfSpaceError
                        userInfo:nil];

    NSError *startError = [self startAndWait];

    XCTAssertEqualObjects(startError.domain, NSCocoaErrorDomain);
    XCTAssertEqual(startError.code, NSFileWriteOutOfSpaceError);
    [self waitForExpectations:@[_threadExited] timeout:5];
}


@end


#endif
