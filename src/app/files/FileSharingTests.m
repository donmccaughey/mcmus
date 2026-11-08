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


#pragma mark - start tests


- (void)testStartTakesSnapshotOfMusicRootDirectory;
{
    [_fileSharing start];

    XCTAssertTrue(_fileSharing.isSharing);
    XCTAssertNil(_fileSharing.error);
    XCTAssertEqual(_changes.count, 1UL);
    XCTAssertEqualObjects(_fileSystem.clonedSources, @[@"/Users/user/Music"]);
    XCTAssertEqualObjects(_fileSystem.clonedDestinations, @[@"/container/AppSupport/snapshot"]);
}


- (void)testStartReportsCloneFailure;
{
    _fileSystem.cloneFileToFileError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                           code:EXDEV
                                                       userInfo:nil];

    [_fileSharing start];

    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, NSPOSIXErrorDomain);
    XCTAssertEqual(_fileSharing.error.code, EXDEV);
    XCTAssertEqual(_changes.count, 1UL);
}


- (void)testStartReportsMissingApplicationSupportDirectory;
{
    _fileSystem.applicationSupportDirectoryURL = nil;

    [_fileSharing start];

    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, FileSystemFakeErrorDomain);
    XCTAssertEqual(_fileSystem.clonedSources.count, 0UL);
}


- (void)testStartReportsMissingMusicRootDirectory;
{
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:[PreferencesFake new]];
    FileSharing *fileSharing = [[FileSharing alloc] initWithStore:store fileSystem:_fileSystem];

    [fileSharing start];

    XCTAssertFalse(fileSharing.isSharing);
    XCTAssertNotNil(fileSharing.error);
    XCTAssertEqual(_fileSystem.clonedSources.count, 0UL);
}


#pragma mark - stop tests


- (void)testStopRemovesSnapshot;
{
    [_fileSharing start];

    [_fileSharing stop];

    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertNil(_fileSharing.error);
    XCTAssertEqual(_changes.count, 2UL);
}


- (void)testStopReportsRemoveFailure;
{
    [_fileSharing start];
    _fileSystem.removeItemAtURLError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                           code:NSFileWriteNoPermissionError
                                                       userInfo:nil];

    [_fileSharing stop];

    XCTAssertFalse(_fileSharing.isSharing);
    XCTAssertEqualObjects(_fileSharing.error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(_fileSharing.error.code, NSFileWriteNoPermissionError);
    XCTAssertEqual(_changes.count, 2UL);
}


@end


#endif
