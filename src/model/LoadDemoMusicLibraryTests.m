#import <XCTest/XCTest.h>

#import "Folder.h"
#import "LoadDemoMusicLibrary.h"
#import "Track.h"

static NSString *const trackPath = @"/Bundle/demo-track.mp3";

@interface LoadDemoMusicLibraryTests : XCTestCase
@end

@implementation LoadDemoMusicLibraryTests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

// The fixtures use single quotes so they read without escapes.
- (LoadResult *)loadResult:(NSString *)json {
    NSString *quoted = [json stringByReplacingOccurrencesOfString:@"'" withString:@"\""];
    return loadDemoMusicLibrary([quoted dataUsingEncoding:NSUTF8StringEncoding], trackPath);
}

- (MusicLibrary *)load:(NSString *)json {
    return [self loadResult:json].library;
}

- (Track *)track:(NSString *)name {
    return [self track:name album:nil artist:nil];
}

- (Track *)track:(NSString *)name album:(NSString *)album {
    return [self track:name album:album artist:nil];
}

- (Track *)track:(NSString *)name album:(NSString *)album artist:(NSString *)artist {
    return [[Track alloc] initWithTrackName:name
                                  albumName:album ?: Track.noAlbum
                                 artistName:artist ?: Track.noArtist
                                       path:trackPath];
}

- (void)testRootDirectoryNameBecomesRootPath {
    MusicLibrary *library = [self load:@"[{'type':'directory','name':'/Users/demo/Music','contents':[]}]"];

    XCTAssertTrue(library.isEmpty);
    XCTAssertEqualObjects(library.rootFolder.path, @"/Users/demo/Music");
    XCTAssertEqualObjects(library.rootFolder.name, Folder.rootName);
}

- (void)testRootDirectoryWithoutNameUsesSlash {
    LoadResult *result = [self loadResult:
        @"[{'type':'directory','contents':[{'type':'file','name':'Song.mp3'}]}]"];

    XCTAssertEqualObjects(result.library.rootFolder.path, @"/");
    XCTAssertEqualObjects(result.library.rootFolder.children, @[[self track:@"Song"]]);
    XCTAssertEqual(result.errors.count, 0UL);
}

- (void)testRootDirectoryWithoutContentsGivesEmptyLibrary {
    MusicLibrary *library = [self load:@"[{'type':'directory','name':'/Music'}]"];

    XCTAssertTrue(library.isEmpty);
    XCTAssertEqualObjects(library.rootFolder.path, @"/Music");
}

- (void)testFirstDirectoryEntryIsUsedAsRoot {
    MusicLibrary *library = [self load:
        @"["
        "    {'type':'report','directories':1,'files':1},"
        "    {'type':'directory','name':'/Music','contents':[{'type':'file','name':'Song.mp3'}]},"
        "    {'type':'directory','name':'/Other','contents':[{'type':'file','name':'Other.mp3'}]}"
        "]"];

    XCTAssertEqualObjects(library.rootFolder.path, @"/Music");
    XCTAssertEqualObjects(library.rootFolder.children, @[[self track:@"Song"]]);
}

- (void)testEveryTrackPointsAtTheDemoTrackFile {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'file','name':'One.mp3'},"
        "    {'type':'directory','name':'Album','contents':["
        "        {'type':'file','name':'Two.m4a'}"
        "    ]}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, (@[
        [[Folder alloc] initWithPath:@"/Music/Album" name:@"Album" children:@[
            [self track:@"Two" album:@"Album"],
        ]],
        [self track:@"One"],
    ]));
}

- (void)testFolderNamesBecomeAlbumAndArtist {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'directory','name':'Artist','contents':["
        "        {'type':'directory','name':'Album','contents':["
        "            {'type':'file','name':'01 Song.mp3'}"
        "        ]}"
        "    ]}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, (@[
        [[Folder alloc] initWithPath:@"/Music/Artist" name:@"Artist" children:@[
            [[Folder alloc] initWithPath:@"/Music/Artist/Album" name:@"Album" children:@[
                [self track:@"01 Song" album:@"Album" artist:@"Artist"],
            ]],
        ]],
    ]));
}

- (void)testDeeperFoldersUseNearestTwoAncestors {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'directory','name':'Genre','contents':["
        "        {'type':'directory','name':'Artist','contents':["
        "            {'type':'directory','name':'Album','contents':["
        "                {'type':'file','name':'Song.mp3'}"
        "            ]}"
        "        ]}"
        "    ]}"
        "]}]"];

    NSArray<id<FolderChild>> *genre = library.rootFolder.children.firstObject.children;
    XCTAssertNotNil(genre);
    NSArray<id<FolderChild>> *artist = genre.firstObject.children;
    XCTAssertNotNil(artist);
    NSArray<id<FolderChild>> *album = artist.firstObject.children;
    XCTAssertNotNil(album);
    XCTAssertEqualObjects(album, @[[self track:@"Song" album:@"Album" artist:@"Artist"]]);
}

- (void)testOnlyMusicFilesBecomeTracks {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'file','name':'cover.jpg'},"
        "    {'type':'file','name':'notes.txt'},"
        "    {'type':'file','name':'README'},"
        "    {'type':'file','name':'Loud.MP3'},"
        "    {'type':'file','name':'Quiet.M4A'}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, (@[
        [self track:@"Loud"],
        [self track:@"Quiet"],
    ]));
}

- (void)testHiddenFilesAndDirectoriesAreSkipped {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'file','name':'.DS_Store'},"
        "    {'type':'file','name':'._Song.mp3'},"
        "    {'type':'directory','name':'.hidden','contents':["
        "        {'type':'file','name':'Secret.mp3'}"
        "    ]},"
        "    {'type':'file','name':'Song.mp3'}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, @[[self track:@"Song"]]);
}

- (void)testITunesLPPackagesAreSkipped {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'directory','name':'Album.itlp','contents':["
        "        {'type':'file','name':'Inside.mp3'}"
        "    ]},"
        "    {'type':'directory','name':'Loud.ITLP','contents':[]},"
        "    {'type':'file','name':'Song.mp3'}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, @[[self track:@"Song"]]);
}

- (void)testEntriesWithoutNamesAreSkipped {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'file'},"
        "    {'type':'directory','contents':[{'type':'file','name':'Song.mp3'}]},"
        "    {'type':'file','name':'Song.mp3'}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, @[[self track:@"Song"]]);
}

- (void)testEntriesThatAreNeitherFilesNorDirectoriesAreSkipped {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'link','name':'Link.mp3'},"
        "    {'type':'file','name':'Song.mp3'}"
        "]}]"];

    XCTAssertEqualObjects(library.rootFolder.children, @[[self track:@"Song"]]);
}

- (void)testChildrenAreSortedNaturallyByName {
    MusicLibrary *library = [self load:
        @"[{'type':'directory','name':'/Music','contents':["
        "    {'type':'file','name':'Track 10.mp3'},"
        "    {'type':'file','name':'track 2.mp3'},"
        "    {'type':'directory','name':'B folder','contents':[]},"
        "    {'type':'directory','name':'a folder','contents':[]}"
        "]}]"];

    XCTAssertEqualObjects([library.rootFolder.children valueForKey:@"name"], (@[
        @"a folder", @"B folder", @"track 2", @"Track 10",
    ]));
}

- (void)testInvalidJSONGivesEmptyLibraryAndReportsFailure {
    LoadResult *result = [self loadResult:@"not json"];

    XCTAssertTrue(result.library.isEmpty);
    XCTAssertNil(result.library.rootFolder.path);
    XCTAssertEqual(result.errors.count, 1UL);
    NSError *error = result.errors.firstObject;
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSPropertyListReadCorruptError);
}

- (void)testMissingDirectoryEntryGivesEmptyLibraryAndReportsFailure {
    LoadResult *result = [self loadResult:@"[{'type':'report','directories':0,'files':0}]"];

    XCTAssertTrue(result.library.isEmpty);
    XCTAssertNil(result.library.rootFolder.path);
    XCTAssertEqual(result.errors.count, 1UL);
    NSError *error = result.errors.firstObject;
    XCTAssertEqualObjects(error.domain, LoadDemoErrorDomain);
    XCTAssertEqual(error.code, LoadDemoErrorCodeNoDirectoryEntry);
}

@end
