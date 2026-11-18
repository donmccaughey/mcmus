#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"
#import "Snapshot.h"


@interface SnapshotTests : XCTestCase
@end


@implementation SnapshotTests {
    NSURL *_musicDir;
    NSURL *_workingDir;
}


- (void)setUp;
{
    [super setUp];
    _musicDir = [NSURL fileURLWithPath:@"/Users/user/Music" isDirectory:YES];
    _workingDir = [NSURL fileURLWithPath:@"/container/AppSupport"
                             isDirectory:YES];
}


#pragma mark - takeSnapshot() tests


- (void)testTakeSnapshotWhenRemoveItemFails;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileReadUnknownError
                        userInfo:nil];

    NSError *error = nil;
    NSURL *snapshotURL =
        takeSnapshot(_musicDir, _workingDir, fileSystem, &error);

    XCTAssertNil(snapshotURL);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSFileReadUnknownError);
}


- (void)testTakeSnapshotWhenCloneFileFails;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileNoSuchFileError
                        userInfo:nil];
    fileSystem.cloneFileToFileError =
        [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTSUP userInfo:nil];

    NSError *error = nil;
    NSURL *snapshotURL =
        takeSnapshot(_musicDir, _workingDir, fileSystem, &error);

    XCTAssertNil(snapshotURL);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, NSPOSIXErrorDomain);
    XCTAssertEqual(error.code, ENOTSUP);
}


- (void)testTakeSnapshotWhenOldSnapshotDoesNotExist;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileNoSuchFileError
                        userInfo:nil];
    fileSystem.cloneFileToFileError = nil;

    NSError *error = nil;
    NSURL *snapshotURL =
        takeSnapshot(_musicDir, _workingDir, fileSystem, &error);

    XCTAssertEqualObjects(snapshotURL.path, @"/container/AppSupport/snapshot");
    XCTAssertNil(error);
    XCTAssertEqualObjects(fileSystem.clonedSources, @[@"/Users/user/Music"]);
    XCTAssertEqualObjects(
        fileSystem.clonedDestinations, @[@"/container/AppSupport/snapshot"]);
}


- (void)testTakeSnapshotRemovesOldSnapshotButNotWorkingDir;
{
    FileSystemFake *fileSystem = [FileSystemFake new];

    NSError *error = nil;
    NSURL *snapshotURL =
        takeSnapshot(_musicDir, _workingDir, fileSystem, &error);

    XCTAssertNotNil(snapshotURL);
    XCTAssertEqualObjects(
        fileSystem.removedPaths, @[@"/container/AppSupport/snapshot"]);
}


#pragma mark - removeSnapshot() tests


- (void)testRemoveSnapshotWhenRemoveItemFails;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileReadUnknownError
                        userInfo:nil];

    NSError *error = nil;
    BOOL removed = removeSnapshot(_workingDir, fileSystem, &error);

    XCTAssertFalse(removed);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSFileReadUnknownError);
}


- (void)testRemoveSnapshotWhenSnapshotDirDoesNotExist;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileNoSuchFileError
                        userInfo:nil];

    NSError *error = nil;
    BOOL removed = removeSnapshot(_workingDir, fileSystem, &error);

    XCTAssertTrue(removed);
    XCTAssertNil(error);
}


- (void)testRemoveSnapshotWhenSnapshotDirExists;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError = nil;

    NSError *error = nil;
    BOOL removed = removeSnapshot(_workingDir, fileSystem, &error);

    XCTAssertTrue(removed);
    XCTAssertNil(error);
    XCTAssertEqualObjects(
        fileSystem.removedPaths, @[@"/container/AppSupport/snapshot"]);
}


@end


#endif
