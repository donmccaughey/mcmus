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
    NSURL *_snapshotDir;
}


- (void)setUp;
{
    [super setUp];
    _musicDir = [NSURL fileURLWithPath:@"/Users/user/Music" isDirectory:YES];
    _snapshotDir = [NSURL fileURLWithPath:@"/container/AppSupport"
                              isDirectory:YES];
}


#pragma mark - getSnapshotDirURL() tests


- (void)testGetSnapshotDirURL;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.applicationSupportDirectoryURL =
        [NSURL fileURLWithPath:@"/tmp/snapshot/appsupport" isDirectory:YES];

    NSError *error = nil;
    NSURL *snapshotDir = getSnapshotDirURL(fileSystem, &error);

    XCTAssertEqualObjects(
        @"/tmp/snapshot/appsupport/snapshot", snapshotDir.path);
}


- (void)testGetSnapshotDirURLWhenGetAppSupportDirFails;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.applicationSupportDirectoryURL = nil;

    NSError *error = nil;
    NSURL *snapshotDir = getSnapshotDirURL(fileSystem, &error);

    XCTAssertNil(snapshotDir);
    XCTAssertEqual(error.domain, FileSystemFakeErrorDomain);
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
    BOOL tookSnapshot =
        takeSnapshot(_musicDir, _snapshotDir, fileSystem, &error);

    XCTAssertFalse(tookSnapshot);
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
    BOOL tookSnapshot =
        takeSnapshot(_musicDir, _snapshotDir, fileSystem, &error);

    XCTAssertFalse(tookSnapshot);
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
    BOOL tookSnapshot =
        takeSnapshot(_musicDir, _snapshotDir, fileSystem, &error);

    XCTAssertTrue(tookSnapshot);
    XCTAssertNil(error);
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
    BOOL removed = removeSnapshot(_snapshotDir, fileSystem, &error);

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
    BOOL removed = removeSnapshot(_snapshotDir, fileSystem, &error);

    XCTAssertTrue(removed);
    XCTAssertNil(error);
}


- (void)testRemoveSnapshotWhenSnapshotDirExists;
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    fileSystem.removeItemAtURLError = nil;

    NSError *error = nil;
    BOOL removed = removeSnapshot(_snapshotDir, fileSystem, &error);

    XCTAssertTrue(removed);
    XCTAssertNil(error);
}


@end


#endif
