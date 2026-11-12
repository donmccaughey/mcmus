#import <XCTest/XCTest.h>

#import "Folder.h"
#import "Track.h"

@interface FolderTests : XCTestCase
@end

@implementation FolderTests

- (Track *)track:(NSString *)name
{
    return [[Track alloc]
        initWithTrackName:name
                albumName:Track.noAlbum
               artistName:Track.noArtist
                     path:[NSString stringWithFormat:@"/Music/%@.mp3", name]];
}

- (void)testEmptyFolderHasNoTrackDescendants
{
    XCTAssertEqual([[Folder alloc] init].trackDescendants.count, 0UL);
}

- (void)testDirectTracksAreDescendantsInOrder
{
    Track *first = [self track:@"A"];
    Track *second = [self track:@"B"];
    Folder *folder = [[Folder alloc] initWithPath:@"/Music"
                                             name:@"Music"
                                         children:@[first, second]];

    XCTAssertEqualObjects(folder.trackDescendants, (@[first, second]));
}

- (void)testNestedTracksAreDescendantsInPreorder
{
    Track *loose = [self track:@"Loose"];
    Track *albumOne = [self track:@"Album One Song"];
    Track *albumTwo = [self track:@"Album Two Song"];
    Track *single = [self track:@"Single"];
    Folder *folder = [[Folder alloc]
        initWithPath:@"/Music"
                name:@"Music"
            children:@[
                [[Folder alloc]
                    initWithPath:@"/Music/Artist"
                            name:@"Artist"
                        children:@[
                            [[Folder alloc] initWithPath:@"/Music/Artist/One"
                                                    name:@"One"
                                                children:@[albumOne]],
                            single,
                            [[Folder alloc] initWithPath:@"/Music/Artist/Two"
                                                    name:@"Two"
                                                children:@[albumTwo]],
                        ]],
                loose,
            ]];

    XCTAssertEqualObjects(
        folder.trackDescendants, (@[albumOne, single, albumTwo, loose]));
}

@end
