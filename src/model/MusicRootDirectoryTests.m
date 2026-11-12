#import <XCTest/XCTest.h>

#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"
#import "MusicRootDirectory.h"
#import "PreferencesFake.h"

#if TARGET_OS_OSX
@interface MusicRootDirectoryTests : XCTestCase
@end

@implementation MusicRootDirectoryTests {
    NSData *_savedBookmark;
    NSURL *_systemMusicDirectory;
}

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    _savedBookmark = [FileSystemFake bookmarkForPath:@"/Saved/Music"];
    _systemMusicDirectory = [NSURL fileURLWithPath:@"/Users/me/Music"
                                       isDirectory:YES];
}

- (void)testUsesResolvedBookmarkAndStartsAccess
{
    PreferencesFake *preferences = [[PreferencesFake alloc]
        initWithMusicRootDirectoryBookmark:_savedBookmark];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];

    NSError *error;
    MusicRootDirectory *root =
        [MusicRootDirectory locateWithFileSystem:fileSystem
                                     preferences:preferences
                                           error:&error];

    XCTAssertNotNil(root);
    XCTAssertEqualObjects(root.url.path, @"/Saved/Music");
    XCTAssertTrue(root.url.hasDirectoryPath);
    XCTAssertTrue(root.isSecurityScoped);
    XCTAssertEqualObjects(fileSystem.started, @[@"/Saved/Music"]);
    XCTAssertEqual(fileSystem.bookmarked.count, 0UL);
    XCTAssertEqualObjects(
        preferences.musicRootDirectoryBookmark, _savedBookmark);
}

- (void)testRefreshesStaleBookmark
{
    PreferencesFake *preferences = [[PreferencesFake alloc]
        initWithMusicRootDirectoryBookmark:_savedBookmark];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    fileSystem.staleBookmarks = [NSSet setWithObject:@"/Saved/Music"];

    NSError *error;
    MusicRootDirectory *root =
        [MusicRootDirectory locateWithFileSystem:fileSystem
                                     preferences:preferences
                                           error:&error];

    XCTAssertNotNil(root);
    XCTAssertEqualObjects(root.url.path, @"/Saved/Music");
    XCTAssertTrue(root.isSecurityScoped);
    XCTAssertEqualObjects(fileSystem.bookmarked, @[@"/Saved/Music"]);
    XCTAssertEqualObjects(
        preferences.musicRootDirectoryBookmark, _savedBookmark);
}

- (void)testFallsBackToSystemMusicDirectoryWhenBookmarkDoesNotResolve
{
    PreferencesFake *preferences = [[PreferencesFake alloc]
        initWithMusicRootDirectoryBookmark:_savedBookmark];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    fileSystem.unresolvableBookmarks = [NSSet setWithObject:@"/Saved/Music"];
    fileSystem.musicDirectoryURL = _systemMusicDirectory;

    NSError *error;
    MusicRootDirectory *root =
        [MusicRootDirectory locateWithFileSystem:fileSystem
                                     preferences:preferences
                                           error:&error];

    XCTAssertNotNil(root);
    XCTAssertEqualObjects(root.url.path, @"/Users/me/Music");
    XCTAssertFalse(root.isSecurityScoped);
    XCTAssertEqual(fileSystem.started.count, 0UL);
    XCTAssertEqualObjects(
        preferences.musicRootDirectoryBookmark, _savedBookmark);
}

- (void)testFallsBackToSystemMusicDirectoryWhenAccessIsDenied
{
    PreferencesFake *preferences = [[PreferencesFake alloc]
        initWithMusicRootDirectoryBookmark:_savedBookmark];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    fileSystem.inaccessiblePaths = [NSSet setWithObject:@"/Saved/Music"];
    fileSystem.musicDirectoryURL = _systemMusicDirectory;

    NSError *error;
    MusicRootDirectory *root =
        [MusicRootDirectory locateWithFileSystem:fileSystem
                                     preferences:preferences
                                           error:&error];

    XCTAssertNotNil(root);
    XCTAssertEqualObjects(root.url.path, @"/Users/me/Music");
    XCTAssertFalse(root.isSecurityScoped);
    XCTAssertEqual(fileSystem.started.count, 0UL);
}

- (void)testUsesSystemMusicDirectoryWhenNoBookmarkIsSaved
{
    PreferencesFake *preferences = [[PreferencesFake alloc] init];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    fileSystem.musicDirectoryURL = _systemMusicDirectory;

    NSError *error;
    MusicRootDirectory *root =
        [MusicRootDirectory locateWithFileSystem:fileSystem
                                     preferences:preferences
                                           error:&error];

    XCTAssertNotNil(root);
    XCTAssertEqualObjects(root.url.path, @"/Users/me/Music");
    XCTAssertFalse(root.isSecurityScoped);
    XCTAssertEqual(fileSystem.started.count, 0UL);
    XCTAssertNil(preferences.musicRootDirectoryBookmark);
}

- (void)testFailsWhenSystemMusicDirectoryIsUnavailable
{
    PreferencesFake *preferences = [[PreferencesFake alloc] init];

    NSError *error;
    MusicRootDirectory *root =
        [MusicRootDirectory locateWithFileSystem:[[FileSystemFake alloc] init]
                                     preferences:preferences
                                           error:&error];

    XCTAssertNil(root);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(
        fileSystemFakeErrorPath(error), @"getMusicDirectoryURL");
    XCTAssertNil(preferences.musicRootDirectoryBookmark);
}

- (void)testChoosingSavesBookmarkAndStartsAccess
{
    PreferencesFake *preferences = [[PreferencesFake alloc] init];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    NSURL *chosen = [NSURL fileURLWithPath:@"/Other/Music" isDirectory:YES];

    MusicRootDirectory *root = [MusicRootDirectory choose:chosen
                                               fileSystem:fileSystem
                                              preferences:preferences];

    XCTAssertEqualObjects(root.url.path, @"/Other/Music");
    XCTAssertTrue(root.isSecurityScoped);
    XCTAssertEqualObjects(preferences.musicRootDirectoryBookmark,
        [FileSystemFake bookmarkForPath:@"/Other/Music"]);
    XCTAssertEqualObjects(fileSystem.started, @[@"/Other/Music"]);
}

- (void)testChoosingKeepsSessionAccessWhenBookmarkCannotBeMade
{
    PreferencesFake *preferences = [[PreferencesFake alloc] init];
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    fileSystem.unbookmarkablePaths = [NSSet setWithObject:@"/Other/Music"];
    NSURL *chosen = [NSURL fileURLWithPath:@"/Other/Music" isDirectory:YES];

    MusicRootDirectory *root = [MusicRootDirectory choose:chosen
                                               fileSystem:fileSystem
                                              preferences:preferences];

    XCTAssertEqualObjects(root.url.path, @"/Other/Music");
    XCTAssertFalse(root.isSecurityScoped);
    XCTAssertNil(preferences.musicRootDirectoryBookmark);
    XCTAssertEqual(fileSystem.started.count, 0UL);
}

- (void)testStopAccessingStopsOnlySecurityScopedRoot
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    NSURL *url = [NSURL fileURLWithPath:@"/Saved/Music" isDirectory:YES];

    [[[MusicRootDirectory alloc] initWithURL:url isSecurityScoped:NO]
        stopAccessingWithFileSystem:fileSystem];
    XCTAssertEqual(fileSystem.stopped.count, 0UL);

    [[[MusicRootDirectory alloc] initWithURL:url isSecurityScoped:YES]
        stopAccessingWithFileSystem:fileSystem];
    XCTAssertEqualObjects(fileSystem.stopped, @[@"/Saved/Music"]);
}

@end
#endif
