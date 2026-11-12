#import <XCTest/XCTest.h>

#import "Folder.h"
#import "FolderChildPasteboard.h"
#import "Track.h"

#if TARGET_OS_OSX
@interface FolderChildPasteboardTests : XCTestCase
@end

@implementation FolderChildPasteboardTests {
    Folder *_folder;
    Track *_track;
}

- (void)setUp
{
    [super setUp];
    _folder = [[Folder alloc]
        initWithPath:@"/Music/Artist"
                name:@"Artist"
            children:@[
                [[Folder alloc]
                    initWithPath:@"/Music/Artist/Album"
                            name:@"Album"
                        children:@[
                            [[Track alloc] initWithTrackName:@"Song"
                                                   albumName:@"Album"
                                                  artistName:@"Artist"
                                                        path:@"/Music/Artist/"
                                                             @"Album/Song.mp3"],
                        ]],
                [[Track alloc] initWithTrackName:@"Single"
                                       albumName:@"Artist"
                                      artistName:Track.noArtist
                                            path:@"/Music/Artist/Single.m4a"],
                [[Folder alloc] initWithPath:@"/Music/Artist/Empty"
                                        name:@"Empty"
                                    children:@[]],
            ]];
    _track = [[Track alloc] initWithTrackName:@"Loose"
                                    albumName:Track.noAlbum
                                   artistName:Track.noArtist
                                         path:@"/Music/Loose.m4a"];
}

- (void)testNestedFolderRoundTripsThroughPasteboardItem
{
    NSPasteboardItem *item =
        [FolderChildPasteboard pasteboardItemForChild:_folder];

    id<FolderChild> child = [FolderChildPasteboard childInItem:item];

    XCTAssertTrue([child isKindOfClass:[Folder class]]);
    XCTAssertEqualObjects(child, _folder);
}

- (void)testTrackRoundTripsThroughPasteboardItem
{
    NSPasteboardItem *item =
        [FolderChildPasteboard pasteboardItemForChild:_track];

    id<FolderChild> child = [FolderChildPasteboard childInItem:item];

    XCTAssertTrue([child isKindOfClass:[Track class]]);
    XCTAssertEqualObjects(child, _track);
    // Track equality only compares paths.
    XCTAssertEqualObjects(child.description, _track.description);
}

- (void)testItemWithoutFolderChildDataYieldsNil
{
    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
    [item setString:@"Song" forType:NSPasteboardTypeString];

    XCTAssertNil([FolderChildPasteboard childInItem:item]);
}

- (void)testReadsEveryItemOnPasteboardInOrder
{
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[
        [FolderChildPasteboard pasteboardItemForChild:_folder],
        [FolderChildPasteboard pasteboardItemForChild:_track],
    ]];

    NSArray<id<FolderChild>> *children =
        [FolderChildPasteboard childrenInPasteboard:pasteboard];
    [pasteboard releaseGlobally];

    XCTAssertEqualObjects(children, (@[_folder, _track]));
}

@end
#endif
