#import <XCTest/XCTest.h>

#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"
#import "Folder.h"
#import "LoadMusicLibrary.h"
#import "Track.h"

@interface LoadMusicLibraryTests : XCTestCase
@end

static NSArray<NSString *> *trackDescriptions(
    NSArray<id<FolderChild>> *children)
{
    return [[children valueForKeyPath:@"@unionOfArrays.trackDescendants"]
        valueForKey:@"description"];
}

// Tracks are equal when their paths are, so equal trees can still differ in
// the tracks' other properties; their descriptions cover all of them.
#define AssertEqualChildren(actual, expected)                                  \
    do {                                                                       \
        XCTAssertEqualObjects(actual, expected);                               \
        XCTAssertEqualObjects(                                                 \
            trackDescriptions(actual), trackDescriptions(expected));           \
    } while (0)

@implementation LoadMusicLibraryTests {
    NSURL *_root;
}

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    _root = [NSURL fileURLWithPath:@"/Music" isDirectory:YES];
}

- (LoadResult *)loadResult:(FileSystemFake *)fileSystem
{
    return loadMusicLibrary(_root, fileSystem);
}

- (MusicLibrary *)load:(FileSystemFake *)fileSystem
{
    return [self loadResult:fileSystem].library;
}

- (Track *)track:(NSString *)name path:(NSString *)path
{
    return [self track:name path:path album:nil artist:nil];
}

- (Track *)track:(NSString *)name path:(NSString *)path album:(NSString *)album
{
    return [self track:name path:path album:album artist:nil];
}

- (Track *)track:(NSString *)name
            path:(NSString *)path
           album:(NSString *)album
          artist:(NSString *)artist
{
    return [[Track alloc] initWithTrackName:name
                                  albumName:album ?: Track.noAlbum
                                 artistName:artist ?: Track.noArtist
                                       path:path];
}

- (void)testEmptyDirectoryGivesEmptyLibrary
{
    MusicLibrary *library = [self load:[[FileSystemFake alloc] init]];

    XCTAssertTrue(library.isEmpty);
    XCTAssertEqualObjects(library.rootFolder.path, @"/Music");
    XCTAssertEqualObjects(library.rootFolder.name, Folder.rootName);
    XCTAssertEqual(library.rootFolder.children.count, 0UL);
}

- (void)testTracksInRootHaveNoAlbumOrArtist
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Song.mp3"];

    LoadResult *result = [self loadResult:fileSystem];

    AssertEqualChildren(result.library.rootFolder.children, (@[
        [self track:@"Song" path:@"/Music/Song.mp3"],
    ]));
    XCTAssertEqual(result.errors.count, 0UL);
}

- (void)testFolderNamesBecomeAlbumAndArtist
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Artist" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Artist/Album"
                   kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Artist/Album/01 Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [[Folder alloc]
            initWithPath:@"/Music/Artist"
                    name:@"Artist"
                children:@[
                    [[Folder alloc]
                        initWithPath:@"/Music/Artist/Album"
                                name:@"Album"
                            children:@[
                                [self track:@"01 Song"
                                       path:@"/Music/Artist/Album/01 Song.mp3"
                                      album:@"Album"
                                     artist:@"Artist"],
                            ]],
                ]],
    ]));
}

- (void)testTrackInTopLevelFolderHasAlbumButNoArtist
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Album" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Album/Song.m4a"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [[Folder alloc] initWithPath:@"/Music/Album"
                                name:@"Album"
                            children:@[
                                [self track:@"Song"
                                       path:@"/Music/Album/Song.m4a"
                                      album:@"Album"],
                            ]],
    ]));
}

- (void)testDeeperFoldersUseNearestTwoAncestors
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Genre" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Genre/Artist"
                   kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Genre/Artist/Album"
                   kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Genre/Artist/Album/Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    NSArray<id<FolderChild>> *genre =
        library.rootFolder.children.firstObject.children;
    XCTAssertNotNil(genre);
    NSArray<id<FolderChild>> *artist = genre.firstObject.children;
    XCTAssertNotNil(artist);
    NSArray<id<FolderChild>> *album = artist.firstObject.children;
    XCTAssertNotNil(album);
    AssertEqualChildren(album, (@[
        [self track:@"Song"
               path:@"/Music/Genre/Artist/Album/Song.mp3"
              album:@"Album"
             artist:@"Artist"],
    ]));
}

- (void)testOnlyMusicFilesBecomeTracks
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/cover.jpg"];
    [fileSystem addPath:@"/Music/notes.txt"];
    [fileSystem addPath:@"/Music/README"];
    [fileSystem addPath:@"/Music/Loud.MP3"];
    [fileSystem addPath:@"/Music/Quiet.M4A"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [self track:@"Loud" path:@"/Music/Loud.MP3"],
        [self track:@"Quiet" path:@"/Music/Quiet.M4A"],
    ]));
}

- (void)testPackagesAreSkipped
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Music Library.musiclibrary"
                   kind:FileSystemFakeKindPackage];
    [fileSystem addPath:@"/Music/Music Library.musiclibrary/Song.mp3"];
    [fileSystem addPath:@"/Music/Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [self track:@"Song" path:@"/Music/Song.mp3"],
    ]));
}

- (void)testEntriesThatAreNeitherFilesNorDirectoriesAreSkipped
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Link.mp3" kind:FileSystemFakeKindOther];
    [fileSystem addPath:@"/Music/Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [self track:@"Song" path:@"/Music/Song.mp3"],
    ]));
}

- (void)testLocalizedNamesAreUsedForDisplay
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Musica"
                   kind:FileSystemFakeKindDirectory
          localizedName:@"Música"];
    [fileSystem addPath:@"/Music/Musica/Hidden.mp3"
                   kind:FileSystemFakeKindFile
          localizedName:@"Hidden"];
    [fileSystem addPath:@"/Music/Musica/Shown.mp3"
                   kind:FileSystemFakeKindFile
          localizedName:@"Shown.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [[Folder alloc] initWithPath:@"/Music/Musica"
                                name:@"Música"
                            children:@[
                                [self track:@"Hidden"
                                       path:@"/Music/Musica/Hidden.mp3"
                                      album:@"Música"],
                                [self track:@"Shown"
                                       path:@"/Music/Musica/Shown.mp3"
                                      album:@"Música"],
                            ]],
    ]));
}

- (void)testChildrenAreSortedNaturallyByName
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Track 10.mp3"];
    [fileSystem addPath:@"/Music/track 2.mp3"];
    [fileSystem addPath:@"/Music/B folder" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/B folder/Song.mp3"];
    [fileSystem addPath:@"/Music/a folder" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/a folder/Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    XCTAssertEqualObjects([library.rootFolder.children valueForKey:@"name"], (@[
        @"a folder",
        @"B folder",
        @"track 2",
        @"Track 10",
    ]));
}

- (void)testFolderWithoutTracksIsOmitted
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Artwork" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Artwork/cover.jpg"];
    [fileSystem addPath:@"/Music/Artwork/notes.txt"];
    [fileSystem addPath:@"/Music/Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [self track:@"Song" path:@"/Music/Song.mp3"],
    ]));
}

- (void)testFolderWhoseSubfoldersHaveNoTracksIsOmitted
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Lossless" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Lossless/Album"
                   kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Lossless/Album/01 Song.flac"];
    [fileSystem addPath:@"/Music/Artist" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Artist/Album"
                   kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Artist/Album/01 Song.mp3"];

    MusicLibrary *library = [self load:fileSystem];

    AssertEqualChildren(library.rootFolder.children, (@[
        [[Folder alloc]
            initWithPath:@"/Music/Artist"
                    name:@"Artist"
                children:@[
                    [[Folder alloc]
                        initWithPath:@"/Music/Artist/Album"
                                name:@"Album"
                            children:@[
                                [self track:@"01 Song"
                                       path:@"/Music/Artist/Album/01 Song.mp3"
                                      album:@"Album"
                                     artist:@"Artist"],
                            ]],
                ]],
    ]));
}

- (void)testOnlyTracklessFoldersGivesEmptyLibrary
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Empty" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Pictures" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Pictures/cover.jpg"];

    LoadResult *result = [self loadResult:fileSystem];

    XCTAssertTrue(result.library.isEmpty);
    XCTAssertEqual(result.errors.count, 0UL);
}

- (void)testUnlistableRootGivesEmptyLibraryAndReportsFailure
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    fileSystem.unlistableDirectories = [NSSet setWithObject:@"/Music"];

    LoadResult *result = [self loadResult:fileSystem];

    XCTAssertTrue(result.library.isEmpty);
    XCTAssertEqualObjects(result.library.rootFolder.path, @"/Music");
    XCTAssertEqual(result.errors.count, 1UL);
    XCTAssertEqualObjects(
        fileSystemFakeErrorPaths(result.errors), @[@"/Music"]);
}

- (void)testUnlistableSubfolderIsOmittedAndReportsFailure
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Broken" kind:FileSystemFakeKindDirectory];
    [fileSystem addPath:@"/Music/Song.mp3"];
    fileSystem.unlistableDirectories = [NSSet setWithObject:@"/Music/Broken"];

    LoadResult *result = [self loadResult:fileSystem];

    AssertEqualChildren(result.library.rootFolder.children, (@[
        [self track:@"Song" path:@"/Music/Song.mp3"],
    ]));
    XCTAssertEqual(result.errors.count, 1UL);
    XCTAssertEqualObjects(
        fileSystemFakeErrorPaths(result.errors), @[@"/Music/Broken"]);
}

- (void)testUnreadableEntryIsSkippedAndReportsFailure
{
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Bad.mp3"];
    [fileSystem addPath:@"/Music/Good.mp3"];
    fileSystem.unreadableEntries = [NSSet setWithObject:@"/Music/Bad.mp3"];

    LoadResult *result = [self loadResult:fileSystem];

    AssertEqualChildren(result.library.rootFolder.children, (@[
        [self track:@"Good" path:@"/Music/Good.mp3"],
    ]));
    XCTAssertEqual(result.errors.count, 1UL);
    XCTAssertEqualObjects(
        fileSystemFakeErrorPaths(result.errors), @[@"/Music/Bad.mp3"]);
}

@end
