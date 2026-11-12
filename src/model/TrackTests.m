#import <XCTest/XCTest.h>

#import "Track.h"

@interface TrackTests : XCTestCase
@end

@implementation TrackTests

- (Track *)trackNamed:(NSString *)trackName
{
    return [[Track alloc] initWithTrackName:trackName
                                  albumName:@"Album"
                                 artistName:@"Artist"
                                       path:@"/Music/Artist/Album/Song.mp3"];
}

- (void)testInitWithDisplayNameKeepsEveryProperty
{
    Track *track =
        [[Track alloc] initWithDisplayName:@"Song.mp3"
                             pathExtension:@"mp3"
                                      path:@"/Music/Artist/Album/Song.mp3"
                                folderName:@"Album"
                          parentFolderName:@"Artist"];

    XCTAssertEqualObjects(track.trackName, @"Song");
    XCTAssertEqualObjects(track.albumName, @"Album");
    XCTAssertEqualObjects(track.artistName, @"Artist");
    XCTAssertEqualObjects(track.path, @"/Music/Artist/Album/Song.mp3");
}

- (void)testInitWithDisplayNameRejectsNonMusicExtension
{
    Track *track = [[Track alloc] initWithDisplayName:@"cover.jpg"
                                        pathExtension:@"jpg"
                                                 path:@"/Music/cover.jpg"
                                           folderName:nil
                                     parentFolderName:nil];

    XCTAssertNil(track);
}

- (void)testTracksWithSamePathAreEqualWhateverElseDiffers
{
    Track *loaded = [self trackNamed:@"Song"];
    Track *bare =
        [[Track alloc] initWithTrackName:@"Other"
                               albumName:Track.noAlbum
                              artistName:Track.noArtist
                                    path:@"/Music/Artist/Album/Song.mp3"];

    XCTAssertEqualObjects(loaded, bare);
    XCTAssertEqual(loaded.hash, bare.hash);
}

- (void)testTracksWithDifferentPathsAreNotEqual
{
    Track *first =
        [[Track alloc] initWithTrackName:@"Song"
                               albumName:@"Album"
                              artistName:@"Artist"
                                    path:@"/Music/Artist/Album/Song.mp3"];
    Track *second =
        [[Track alloc] initWithTrackName:@"Song"
                               albumName:@"Album"
                              artistName:@"Artist"
                                    path:@"/Music/Artist/Album/Song.m4a"];

    XCTAssertNotEqualObjects(first, second);
    XCTAssertNotEqual(first.hash, second.hash);
}

- (void)testTrackIsNotEqualToItsPath
{
    XCTAssertNotEqualObjects(
        [self trackNamed:@"Song"], @"/Music/Artist/Album/Song.mp3");
}

- (void)testSetHoldsOneTrackPerPath
{
    NSSet<Track *> *tracks = [NSSet setWithArray:@[
        [self trackNamed:@"Song"],
        [self trackNamed:@"Other"],
    ]];

    XCTAssertEqual(tracks.count, 1UL);
}

- (void)testMusicFileExtensionsAreCaseInsensitive
{
    XCTAssertTrue([Track isMusicFileExtension:@"mp3"]);
    XCTAssertTrue([Track isMusicFileExtension:@"M4A"]);
    XCTAssertFalse([Track isMusicFileExtension:@"flac"]);
    XCTAssertFalse([Track isMusicFileExtension:@""]);
}

@end
