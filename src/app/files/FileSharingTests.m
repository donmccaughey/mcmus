#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "FileSharing.h"
#import "FileSystemFake.h"
#import "MusicLibraryStore.h"
#import "NotificationCounter.h"
#import "PreferencesFake.h"


@interface FileSharingTests : XCTestCase
@end


@implementation FileSharingTests
{
    FileSystemFake *_fileSystem;
    MusicLibraryStore *_store;
    FileSharing *_fileSharing;
    NotificationCounter *_changes;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _fileSystem = [FileSystemFake new];
    _fileSystem.applicationSupportDirectoryURL = [NSURL fileURLWithPath:@"/container/AppSupport"
                                                            isDirectory:YES];
    [_fileSystem addPath:@"/Users/user/Music/Song.mp3"];
    PreferencesFake *preferences = [[PreferencesFake alloc]
        initWithMusicRootDirectoryBookmark:[FileSystemFake bookmarkForPath:@"/Users/user/Music"]];
    _store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                               preferences:preferences];
    [self loadStoreAndWait];
    _fileSharing = [[FileSharing alloc] initWithStore:_store fileSystem:_fileSystem];
    _changes = [[NotificationCounter alloc] initWithName:FileSharing.didChangeNotification
                                                  object:_fileSharing];
}


- (void)loadStoreAndWait;
{
    XCTestExpectation *loaded = [self expectationWithDescription:@"loaded"];
    [_store loadInBackgroundIsDemo:NO completion:^{
        [loaded fulfill];
    }];
    [self waitForExpectations:@[loaded] timeout:5];
}


- (void)startAndWait:(FileSharing *)fileSharing;
{
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [fileSharing startWithCompletion:^{
        [started fulfill];
    }];
    [self waitForExpectations:@[started] timeout:5];
}


- (void)stopAndWait:(FileSharing *)fileSharing;
{
    XCTestExpectation *stopped = [self expectationWithDescription:@"stopped"];
    [fileSharing stopWithCompletion:^{
        [stopped fulfill];
    }];
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
    XCTAssertEqualObjects(_fileSystem.clonedDestinations, @[@"/container/AppSupport/snapshot"]);
}


- (void)testStartIsStartingUntilSnapshotCompletes;
{
    XCTestExpectation *started = [self expectationWithDescription:@"started"];
    [_fileSharing startWithCompletion:^{
        [started fulfill];
    }];

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
    [_fileSharing startWithCompletion:^{
        [started fulfill];
    }];

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


- (void)testStartReportsCloneFailure;
{
    _fileSystem.cloneFileToFileError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                           code:EXDEV
                                                       userInfo:nil];

    [self startAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, NSPOSIXErrorDomain);
    XCTAssertEqual(_fileSharing.error.code, EXDEV);
    XCTAssertEqual(_changes.count, 2UL);
}


- (void)testStartReportsMissingApplicationSupportDirectory;
{
    _fileSystem.applicationSupportDirectoryURL = nil;

    [self startAndWait:_fileSharing];

    XCTAssertEqual(_fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, FileSystemFakeErrorDomain);
    XCTAssertEqual(_changes.count, 2UL);
    XCTAssertEqual(_fileSystem.clonedSources.count, 0UL);
}


- (void)testStartReportsMissingMusicRootDirectory;
{
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:[PreferencesFake new]];
    FileSharing *fileSharing = [[FileSharing alloc] initWithStore:store fileSystem:_fileSystem];

    [self startAndWait:fileSharing];

    XCTAssertEqual(fileSharing.state, FileSharingStateOff);
    XCTAssertFalse(fileSharing.isSharing);
    XCTAssertNotNil(fileSharing.error);
    XCTAssertEqual(_fileSystem.clonedSources.count, 0UL);
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
    [_fileSharing stopWithCompletion:^{
        [stopped fulfill];
    }];

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
    [_fileSharing startWithCompletion:^{
        [started fulfill];
    }];

    [self stopAndWait:_fileSharing];

    [self waitForExpectations:@[started] timeout:5];
    XCTAssertEqual(_fileSharing.state, FileSharingStateSharing);
    XCTAssertTrue(_fileSharing.isSharing);
    XCTAssertEqual(_changes.count, 2UL);
}


- (void)testStopReportsRemoveFailure;
{
    [self startAndWait:_fileSharing];
    _fileSystem.removeItemAtURLError = [NSError errorWithDomain:NSCocoaErrorDomain
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
