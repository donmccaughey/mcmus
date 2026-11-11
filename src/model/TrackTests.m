#import <XCTest/XCTest.h>

#import "Track.h"

@interface TrackTests : XCTestCase
@end

@implementation TrackTests

- (Track *)trackWithSize:(unsigned long long)size {
    return [[Track alloc] initWithTrackName:@"Song"
                                  albumName:@"Album"
                                 artistName:@"Artist"
                                       path:@"/Music/Artist/Album/Song.mp3"
                                       size:size];
}

- (void)testInitWithoutSizeGivesZeroSize {
    Track *track = [[Track alloc] initWithTrackName:@"Song"
                                          albumName:@"Album"
                                         artistName:@"Artist"
                                               path:@"/Music/Artist/Album/Song.mp3"];

    XCTAssertEqual(track.size, 0ULL);
    XCTAssertEqualObjects(track, [self trackWithSize:0]);
}

- (void)testInitWithDisplayNameKeepsSize {
    Track *track = [[Track alloc] initWithDisplayName:@"Song.mp3"
                                        pathExtension:@"mp3"
                                                 path:@"/Music/Artist/Album/Song.mp3"
                                           folderName:@"Album"
                                     parentFolderName:@"Artist"
                                                 size:4096];

    XCTAssertEqualObjects(track, [self trackWithSize:4096]);
}

- (void)testInitWithDisplayNameRejectsNonMusicExtension {
    Track *track = [[Track alloc] initWithDisplayName:@"cover.jpg"
                                        pathExtension:@"jpg"
                                                 path:@"/Music/cover.jpg"
                                           folderName:nil
                                     parentFolderName:nil
                                                 size:4096];

    XCTAssertNil(track);
}

- (void)testTracksWithDifferentSizesAreNotEqual {
    Track *small = [self trackWithSize:4096];
    Track *large = [self trackWithSize:8192];

    XCTAssertNotEqualObjects(small, large);
    XCTAssertNotEqual(small.hash, large.hash);
}

- (void)testTracksWithSameSizeAreEqual {
    XCTAssertEqualObjects([self trackWithSize:4096], [self trackWithSize:4096]);
    XCTAssertEqual([self trackWithSize:4096].hash, [self trackWithSize:4096].hash);
}

- (void)testMusicFileExtensionsAreCaseInsensitive {
    XCTAssertTrue([Track isMusicFileExtension:@"mp3"]);
    XCTAssertTrue([Track isMusicFileExtension:@"M4A"]);
    XCTAssertFalse([Track isMusicFileExtension:@"flac"]);
    XCTAssertFalse([Track isMusicFileExtension:@""]);
}

@end
