#import <XCTest/XCTest.h>

#import "Folder.h"
#import "MusicLibrary.h"
#import "Track.h"

@interface MusicLibraryTests : XCTestCase
@end

@implementation MusicLibraryTests

- (Track *)track:(NSString *)name
{
    return [[Track alloc]
        initWithTrackName:name
                albumName:Track.noAlbum
               artistName:Track.noArtist
                     path:[NSString stringWithFormat:@"/Music/%@.mp3", name]];
}

- (Folder *)folder:(NSString *)name
          children:(NSArray<id<FolderChild>> *)children
{
    return [[Folder alloc]
        initWithPath:[NSString stringWithFormat:@"/Music/%@", name]
                name:name
            children:children];
}

- (void)testEmptyLibraryHasNoTracks
{
    XCTAssertEqualObjects([[MusicLibrary new] getTracks], @[]);
}

- (void)testLibraryWithOnlyEmptyFoldersHasNoTracks
{
    Folder *root = [self folder:@"Music" children:@[
        [self folder:@"Empty" children:@[]],
        [self folder:@"Parent" children:@[
            [self folder:@"Child" children:@[]],
        ]],
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], @[]);
}

- (void)testDirectTracksAreReturnedInOrder
{
    Track *first = [self track:@"A"];
    Track *second = [self track:@"B"];
    Track *third = [self track:@"C"];
    Folder *root = [self folder:@"Music" children:@[first, second, third]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], (@[first, second, third]));
}

- (void)testSiblingFoldersAreReturnedInOrder
{
    Track *first = [self track:@"A"];
    Track *second = [self track:@"B"];
    Track *third = [self track:@"C"];
    Folder *root = [self folder:@"Music" children:@[
        [self folder:@"One" children:@[first]],
        [self folder:@"Two" children:@[second]],
        [self folder:@"Three" children:@[third]],
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], (@[first, second, third]));
}

- (void)testFolderTracksComeBeforeFollowingSiblingTracks
{
    Track *nested = [self track:@"Nested"];
    Track *loose = [self track:@"Loose"];
    Folder *root = [self folder:@"Music" children:@[
        [self folder:@"Album" children:@[nested]],
        loose,
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], (@[nested, loose]));
}

- (void)testTracksBeforeFolderComeBeforeFolderTracks
{
    Track *loose = [self track:@"Loose"];
    Track *nested = [self track:@"Nested"];
    Folder *root = [self folder:@"Music" children:@[
        loose,
        [self folder:@"Album" children:@[nested]],
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], (@[loose, nested]));
}

- (void)testNestedTracksAreReturnedInPreorder
{
    Track *deep = [self track:@"Deep"];
    Track *middle = [self track:@"Middle"];
    Track *shallow = [self track:@"Shallow"];
    Track *loose = [self track:@"Loose"];
    Folder *root = [self folder:@"Music" children:@[
        [self folder:@"Artist" children:@[
            [self folder:@"One" children:@[
                [self folder:@"Disc" children:@[deep]],
            ]],
            middle,
            [self folder:@"Two" children:@[shallow]],
        ]],
        loose,
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects(
        [library getTracks], (@[deep, middle, shallow, loose]));
}

- (void)testEmptyFoldersBetweenTracksAreSkipped
{
    Track *first = [self track:@"A"];
    Track *second = [self track:@"B"];
    Folder *root = [self folder:@"Music" children:@[
        [self folder:@"Empty" children:@[]],
        first,
        [self folder:@"AlsoEmpty" children:@[]],
        [self folder:@"Album" children:@[second]],
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], (@[first, second]));
}

- (void)testTracksMatchRootFolderTrackDescendants
{
    Folder *root = [self folder:@"Music" children:@[
        [self folder:@"Artist" children:@[
            [self folder:@"One"
                children:@[[self track:@"A1"], [self track:@"A2"]]],
            [self track:@"Single"],
            [self folder:@"Two" children:@[[self track:@"B1"]]],
        ]],
        [self track:@"Loose"],
    ]];
    MusicLibrary *library = [[MusicLibrary alloc] initWithRootFolder:root];

    XCTAssertEqualObjects([library getTracks], root.trackDescendants);
}

@end
