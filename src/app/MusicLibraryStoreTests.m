#import <XCTest/XCTest.h>

#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"
#import "Folder.h"
#import "LoadResult.h"
#import "MusicLibrary.h"
#import "MusicLibraryStore.h"
#import "NotificationCounter.h"
#import "PreferencesFake.h"
#import "Track.h"

static NSError *someError(void) {
    return [NSError errorWithDomain:@"SomeError" code:1 userInfo:nil];
}

@interface MusicLibraryStoreTests : XCTestCase
@end

@implementation MusicLibraryStoreTests
{
    MusicLibrary *_library;
    FileSystemFake *_fileSystem;
    PreferencesFake *_preferences;
}

- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    Folder *rootFolder = [[Folder alloc] initWithPath:@"/Music"
                                                 name:Folder.rootName children:@[
        [[Track alloc] initWithTrackName:@"Song"
                               albumName:Track.noAlbum
                              artistName:Track.noArtist
                                    path:@"/Music/Song.mp3"],
    ]];
    _library = [[MusicLibrary alloc] initWithRootFolder:rootFolder];
    _fileSystem = [FileSystemFake new];
    _preferences = [PreferencesFake new];
}

- (void)testNewStoreIsEmptyAndHasNotFailed {
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:_preferences];

    XCTAssertTrue(store.library.isEmpty);
    XCTAssertFalse(store.loadDidFail);
}

- (void)testApplyingSuccessfulResultSetsLibrary {
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:_preferences];

    [store apply:[[LoadResult alloc] initWithLibrary:_library errors:@[]]];

    XCTAssertEqualObjects(store.library.rootFolder, _library.rootFolder);
    XCTAssertFalse(store.loadDidFail);
}

- (void)testApplyingFailedResultReportsFailure {
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:_preferences];

    [store apply:[[LoadResult alloc] initWithLibrary:[[MusicLibrary alloc] init] errors:@[someError()]]];

    XCTAssertTrue(store.library.isEmpty);
    XCTAssertTrue(store.loadDidFail);
}

- (void)testApplyingSuccessfulResultClearsEarlierFailure {
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:_preferences];
    
    [store apply:[[LoadResult alloc] initWithLibrary:[[MusicLibrary alloc] init] errors:@[someError()]]];
    [store apply:[[LoadResult alloc] initWithLibrary:_library errors:@[]]];

    XCTAssertFalse(store.loadDidFail);
}

- (void)testApplyingResultPostsLibraryDidChange {
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:_preferences];
    NotificationCounter *libraryChanges =
        [[NotificationCounter alloc] initWithName:MusicLibraryStore.libraryDidChangeNotification object:store];
    NotificationCounter *rootChanges =
        [[NotificationCounter alloc] initWithName:MusicLibraryStore.musicRootDirectoryDidChangeNotification object:store];

    [store apply:[[LoadResult alloc] initWithLibrary:_library errors:@[]]];

    XCTAssertEqual(libraryChanges.count, 1UL);
    XCTAssertEqual(rootChanges.count, 0UL);
}

#if TARGET_OS_OSX
- (NSArray<NSString *> *)trackNamesInStore:(MusicLibraryStore *)store {
    NSMutableArray<NSString *> *trackNames = [NSMutableArray array];
    for (id<FolderChild> child in store.library.rootFolder.children) {
        if ([child isKindOfClass:[Track class]]) {
            [trackNames addObject:((Track *)child).trackName];
        }
    }
    return trackNames;
}

- (void)loadInBackgroundAndWait:(MusicLibraryStore *)store {
    XCTestExpectation *loaded = [self expectationWithDescription:@"loaded"];
    [store loadInBackgroundIsDemo:NO completion:^{
        [loaded fulfill];
    }];
    [self waitForExpectations:@[loaded] timeout:5];
}

- (void)changeMusicRootDirectoryOfStore:(MusicLibraryStore *)store toURLAndWait:(NSURL *)url {
    XCTestExpectation *loaded = [self expectationWithDescription:@"loaded"];
    [store changeMusicRootDirectoryTo:url completion:^{
        [loaded fulfill];
    }];
    [self waitForExpectations:@[loaded] timeout:5];
}

- (void)testBackgroundLoadLocatesRootAndLoadsLibrary {
    [_fileSystem addPath:@"/Saved/Music/Song.mp3"];
    PreferencesFake *preferences =
        [[PreferencesFake alloc] initWithMusicRootDirectoryBookmark:[FileSystemFake bookmarkForPath:@"/Saved/Music"]];
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:preferences];

    [self loadInBackgroundAndWait:store];

    XCTAssertEqualObjects(store.musicRootDirectory.url.path, @"/Saved/Music");
    XCTAssertFalse(store.loadDidFail);
    XCTAssertEqualObjects([self trackNamesInStore:store], @[@"Song"]);
}

- (void)testBackgroundLoadReportsLocateFailure {
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:[[FileSystemFake alloc] init]
                                                                 preferences:[[PreferencesFake alloc] init]];

    [self loadInBackgroundAndWait:store];

    XCTAssertNil(store.musicRootDirectory);
    XCTAssertTrue(store.loadDidFail);
    XCTAssertTrue(store.library.isEmpty);
    XCTAssertEqual(store.loadErrors.count, 1UL);
    XCTAssertEqualObjects(fileSystemFakeErrorPath(store.loadErrors.firstObject), @"getMusicDirectoryURL");
}

- (void)testChangingRootSavesBookmarkSwapsAccessAndReloads {
    [_fileSystem addPath:@"/Saved/Music/Old.mp3"];
    [_fileSystem addPath:@"/Other/Music/New.mp3"];
    PreferencesFake *preferences =
        [[PreferencesFake alloc] initWithMusicRootDirectoryBookmark:[FileSystemFake bookmarkForPath:@"/Saved/Music"]];
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:preferences];
    [self loadInBackgroundAndWait:store];

    // The root changes before the call returns; the library follows when
    // the load lands.
    XCTestExpectation *loaded = [self expectationWithDescription:@"loaded"];
    [store changeMusicRootDirectoryTo:[NSURL fileURLWithPath:@"/Other/Music" isDirectory:YES] completion:^{
        [loaded fulfill];
    }];

    XCTAssertEqualObjects(preferences.musicRootDirectoryBookmark, [FileSystemFake bookmarkForPath:@"/Other/Music"]);
    XCTAssertEqualObjects(_fileSystem.stopped, @[@"/Saved/Music"]);
    XCTAssertEqualObjects(_fileSystem.started, (@[@"/Saved/Music", @"/Other/Music"]));
    XCTAssertEqualObjects(store.musicRootDirectory.url.path, @"/Other/Music");
    XCTAssertEqualObjects([self trackNamesInStore:store], @[@"Old"]);

    [self waitForExpectations:@[loaded] timeout:5];

    XCTAssertFalse(store.loadDidFail);
    XCTAssertEqualObjects([self trackNamesInStore:store], @[@"New"]);
}

- (void)testChangingRootPostsRootChangeFirstAndLibraryChangeWhenLoaded {
    [_fileSystem addPath:@"/Other/Music/New.mp3"];
    PreferencesFake *preferences =
        [[PreferencesFake alloc] initWithMusicRootDirectoryBookmark:[FileSystemFake bookmarkForPath:@"/Saved/Music"]];
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:preferences];
    [self loadInBackgroundAndWait:store];
    NotificationCounter *rootChanges =
        [[NotificationCounter alloc] initWithName:MusicLibraryStore.musicRootDirectoryDidChangeNotification object:store];
    NotificationCounter *libraryChanges =
        [[NotificationCounter alloc] initWithName:MusicLibraryStore.libraryDidChangeNotification object:store];

    XCTestExpectation *loaded = [self expectationWithDescription:@"loaded"];
    [store changeMusicRootDirectoryTo:[NSURL fileURLWithPath:@"/Other/Music" isDirectory:YES] completion:^{
        [loaded fulfill];
    }];

    XCTAssertEqual(rootChanges.count, 1UL);
    XCTAssertEqual(libraryChanges.count, 0UL);

    [self waitForExpectations:@[loaded] timeout:5];

    XCTAssertEqual(libraryChanges.count, 1UL);
}

- (void)testChoosingCurrentRootAgainDoesNothing {
    PreferencesFake *preferences =
        [[PreferencesFake alloc] initWithMusicRootDirectoryBookmark:[FileSystemFake bookmarkForPath:@"/Saved/Music"]];
    MusicLibraryStore *store = [[MusicLibraryStore alloc] initWithFileSystem:_fileSystem
                                                                 preferences:preferences];
    [self loadInBackgroundAndWait:store];
    NotificationCounter *libraryChanges =
        [[NotificationCounter alloc] initWithName:MusicLibraryStore.libraryDidChangeNotification object:store];
    preferences.musicRootDirectoryBookmark = nil;

    [self changeMusicRootDirectoryOfStore:store toURLAndWait:[NSURL fileURLWithPath:@"/Saved/Music" isDirectory:YES]];

    XCTAssertNil(preferences.musicRootDirectoryBookmark);
    XCTAssertEqual(_fileSystem.stopped.count, 0UL);
    XCTAssertEqual(libraryChanges.count, 0UL);
}
#endif

@end
