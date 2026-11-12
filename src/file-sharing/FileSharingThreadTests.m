#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "FileSharingThread.h"
#import "FileSystemFake.h"


@interface FileSharingThreadTests : XCTestCase
@end


@implementation FileSharingThreadTests {
    FileSystemFake *_fileSystem;
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
    _thread = [[FileSharingThread alloc] initWithFileSystem:_fileSystem];
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


@end


#endif
