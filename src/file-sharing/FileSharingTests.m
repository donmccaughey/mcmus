#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "FileSharing.h"
#import "FileSharingService.h"
#import "FileSystemFake.h"
#import "NetworkFake.h"
#import "NotificationCounter.h"


@interface FileSharingTests : XCTestCase
@end


@implementation FileSharingTests {
    FileSystemFake *_fileSystem;
    NetworkFake *_network;
    NSURL *_musicRootDirectoryURL;
    NSURL *_workingDirectoryURL;
    FileSharing *_fileSharing;
    NotificationCounter *_changes;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _fileSystem = [FileSystemFake new];
    [_fileSystem addPath:@"/Users/user/Music/Song.mp3"];
    _musicRootDirectoryURL = [NSURL fileURLWithPath:@"/Users/user/Music"
                                        isDirectory:YES];
    _workingDirectoryURL = [NSURL fileURLWithPath:@"/container/AppSupport"
                                      isDirectory:YES];
    _network = [NetworkFake new];
    _fileSharing =
        [self fileSharingWithMusicRootDirectoryURL:_musicRootDirectoryURL
                               workingDirectoryURL:_workingDirectoryURL];
    _changes = [[NotificationCounter alloc]
        initWithName:FileSharing.didChangeNotification
              object:_fileSharing];
}


- (FileSharing *)
    fileSharingWithMusicRootDirectoryURL:(nullable NSURL *)musicRootDirectoryURL
                     workingDirectoryURL:(nullable NSURL *)workingDirectoryURL;
{
    return
        [[FileSharing alloc] initWithMusicRootDirectoryURL:musicRootDirectoryURL
                                       workingDirectoryURL:workingDirectoryURL
                                                fileSystem:_fileSystem
                                                   network:_network
                                                     clock:[ClockFake new]];
}


- (void)tearDown;
{
    if (_fileSharing.isSharing) [self stopAndWait:_fileSharing];
    [super tearDown];
}


- (void)startAndWait:(FileSharing *)fileSharing;
{
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [fileSharing startWithCompletion:^{ [started fulfill]; }];
    [self waitForExpectations:@[started] timeout:5];
}


- (void)stopAndWait:(FileSharing *)fileSharing;
{
    XCTestExpectation *stopped = [self expectationWithDescription:@"stopped"];
    [fileSharing stopWithCompletion:^{ [stopped fulfill]; }];
    [self waitForExpectations:@[stopped] timeout:5];
}


#pragma mark - start tests


- (void)testStartTakesSnapshotOfMusicRootDirectory;
{
    [self startAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
    XCTAssertTrue(_fileSharing.isSharing);
    XCTAssertFalse(_fileSharing.isChanging);
    XCTAssertNil(_fileSharing.error);
    XCTAssertEqual(_changes.count, 2UL);
    XCTAssertEqualObjects(_fileSystem.clonedSources, @[@"/Users/user/Music"]);
    XCTAssertEqualObjects(
        _fileSystem.clonedDestinations, @[@"/container/AppSupport/snapshot"]);
}


- (void)testStartIsStartingUntilSnapshotCompletes;
{
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [_fileSharing startWithCompletion:^{ [started fulfill]; }];

    XCTAssertEqual(_fileSharing.state, FileSharingStateStarting);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertTrue(_fileSharing.isChanging);
    XCTAssertEqual(_changes.count, 1UL);

    [self waitForExpectations:@[started] timeout:5];
    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
}


- (void)testStartWhileStartingIsIgnored;
{
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [_fileSharing startWithCompletion:^{ [started fulfill]; }];

    [self startAndWait:_fileSharing];

    [self waitForExpectations:@[started] timeout:5];
    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
    XCTAssertEqual(_changes.count, 2UL);
    XCTAssertEqual(_fileSystem.clonedSources.count, 1UL);
}


- (void)testStartWhileSharingIsIgnored;
{
    [self startAndWait:_fileSharing];

    [self startAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
    XCTAssertEqual(_changes.count, 2UL);
    XCTAssertEqual(_fileSystem.clonedSources.count, 1UL);
}


- (void)testStartReportsMetadataProgressWhileStarting;
{
    for (int i = 0; i < 250; ++i) {
        [_fileSystem
            addPath:[NSString stringWithFormat:
                            @"/container/AppSupport/snapshot/Song %d.mp3", i]];
    }
    NSMutableArray<NSString *> *progress = [NSMutableArray array];
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:FileSharing.didChangeNotification
                    object:_fileSharing
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    FileSharing *fileSharing = notification.object;
                    [progress
                        addObject:[NSString stringWithFormat:@"%lu of %lu",
                                      fileSharing.metadataTracksLoaded,
                                      fileSharing.metadataTotalTracks]];
                }];

    [self startAndWait:_fileSharing];
    [NSNotificationCenter.defaultCenter removeObserver:observer];

    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
    XCTAssertEqualObjects(
        progress, (@[@"0 of 0", @"100 of 250", @"200 of 250", @"0 of 0"]));
}


- (void)testStartReportsCloneFailure;
{
    _fileSystem.cloneFileToFileError =
        [NSError errorWithDomain:NSPOSIXErrorDomain code:EXDEV userInfo:nil];

    [self startAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, NSPOSIXErrorDomain);
    XCTAssertEqual(_fileSharing.error.code, EXDEV);
    XCTAssertEqual(_changes.count, 2UL);
}


- (void)testStartReportsMissingWorkingDirectory;
{
    FileSharing *fileSharing =
        [self fileSharingWithMusicRootDirectoryURL:_musicRootDirectoryURL
                               workingDirectoryURL:nil];

    [self startAndWait:fileSharing];

    XCTAssertEqual(fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(fileSharing.isSharing);
    XCTAssertEqualObjects(
        fileSharing.error.localizedDescription, @"No working directory.");
    XCTAssertEqual(_fileSystem.clonedSources.count, 0UL);
}


- (void)testStartReportsMissingMusicRootDirectory;
{
    FileSharing *fileSharing =
        [self fileSharingWithMusicRootDirectoryURL:nil
                               workingDirectoryURL:_workingDirectoryURL];

    [self startAndWait:fileSharing];

    XCTAssertEqual(fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(fileSharing.isSharing);
    XCTAssertNotNil(fileSharing.error);
    XCTAssertEqual(_fileSystem.clonedSources.count, 0UL);
}


- (void)testStartReportsListenFailure;
{
    _network.port = 51234;
    _network.listenError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:EADDRINUSE
                                           userInfo:nil];

    [self startAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertEqualObjects(_fileSharing.error, _network.listenError);
    XCTAssertEqual(_fileSharing.port, 0);
}


- (void)testPortIsTheServerPortOnlyWhileSharing;
{
    _network.port = 51234;
    XCTAssertEqual(_fileSharing.port, 0);

    [self startAndWait:_fileSharing];
    XCTAssertEqual(_fileSharing.port, 51234);

    [self stopAndWait:_fileSharing];
    XCTAssertEqual(_fileSharing.port, 0);
}


#pragma mark - connected device tests


// The server's reports reach the file sharing object on the main queue, so
// the tests wait for a block queued behind them.
- (void)waitForMainQueue;
{
    XCTestExpectation *drained = [self expectationWithDescription:@"drained"];
    dispatch_async(dispatch_get_main_queue(), ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:5];
}


- (void)reportClient:(nullable NSString *)deviceName;
{
    id<FileSharingClient> client = (id<FileSharingClient>)_fileSharing;
    if (deviceName) {
        [client serverDidConnectClient:deviceName];
    } else {
        [client serverIsWaitingForClient];
    }
    [self waitForMainQueue];
}


- (void)testNoDeviceIsConnectedWhenSharingStarts;
{
    [self startAndWait:_fileSharing];
    [self waitForMainQueue];

    XCTAssertNil(_fileSharing.connectedDeviceName);
    XCTAssertEqual(_changes.count, 2UL);
}


- (void)testConnectedClientSetsConnectedDeviceName;
{
    [self startAndWait:_fileSharing];

    [self reportClient:@"Don's iPhone"];

    XCTAssertEqualObjects(_fileSharing.connectedDeviceName, @"Don's iPhone");
    XCTAssertEqual(_changes.count, 3UL);
}


- (void)testRepeatedReportOfSameClientIsNotAChange;
{
    [self startAndWait:_fileSharing];
    [self reportClient:@"Don's iPhone"];

    [self reportClient:@"Don's iPhone"];

    XCTAssertEqual(_changes.count, 3UL);
}


- (void)testWaitingForClientClearsConnectedDeviceName;
{
    [self startAndWait:_fileSharing];
    [self reportClient:@"Don's iPhone"];

    [self reportClient:nil];

    XCTAssertNil(_fileSharing.connectedDeviceName);
    XCTAssertEqual(_changes.count, 4UL);
}


- (void)testStopClearsConnectedDeviceName;
{
    [self startAndWait:_fileSharing];
    [self reportClient:@"Don's iPhone"];

    [self stopAndWait:_fileSharing];

    XCTAssertNil(_fileSharing.connectedDeviceName);
}


- (void)testClientReportedWhileOffIsIgnored;
{
    [self reportClient:@"Don's iPhone"];

    XCTAssertNil(_fileSharing.connectedDeviceName);
    XCTAssertEqual(_changes.count, 0UL);
}


#pragma mark - stop tests


- (void)testStopRemovesSnapshot;
{
    [self startAndWait:_fileSharing];

    [self stopAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertNil(_fileSharing.error);
    XCTAssertEqual(_changes.count, 4UL);
}


- (void)testStopIsStoppingUntilRemovalCompletes;
{
    [self startAndWait:_fileSharing];

    XCTestExpectation *stopped = [self expectationWithDescription:@"stopped"];
    [_fileSharing stopWithCompletion:^{ [stopped fulfill]; }];

    XCTAssertEqual(_fileSharing.state, FileSharingStateStopping);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertTrue(_fileSharing.isChanging);
    XCTAssertEqual(_changes.count, 3UL);

    [self waitForExpectations:@[stopped] timeout:5];
    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
}


- (void)testStopWhileOffIsIgnored;
{
    [self stopAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertNil(_fileSharing.error);
    XCTAssertEqual(_changes.count, 0UL);
}


- (void)testStopWhileStartingIsIgnored;
{
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [_fileSharing startWithCompletion:^{ [started fulfill]; }];

    [self stopAndWait:_fileSharing];

    [self waitForExpectations:@[started] timeout:5];
    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
    XCTAssertTrue(_fileSharing.isSharing);
    XCTAssertEqual(_changes.count, 2UL);
}


- (void)testStopClosesServer;
{
    [self startAndWait:_fileSharing];
    XCTAssertFalse(_network.listener.isClosed);

    [self stopAndWait:_fileSharing];

    XCTAssertTrue(_network.listener.isClosed);
    XCTAssertTrue(_network.advertisement.isClosed);
}


- (void)testStopReportsRemoveFailure;
{
    [self startAndWait:_fileSharing];
    _fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileWriteNoPermissionError
                        userInfo:nil];

    [self stopAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(_fileSharing.error.code, NSFileWriteNoPermissionError);
    XCTAssertEqual(_changes.count, 4UL);
}


@end


#endif
