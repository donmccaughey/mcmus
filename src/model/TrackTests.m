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

- (Track *)trackWithFileHash:(NSUInteger)fileHash {
    return [[Track alloc] initWithTrackName:@"Song"
                                  albumName:@"Album"
                                 artistName:@"Artist"
                                       path:@"/Music/Artist/Album/Song.mp3"
                                       size:4096
                                   fileHash:fileHash];
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
                                                 size:4096
                                             fileHash:0];

    XCTAssertEqualObjects(track, [self trackWithSize:4096]);
}

- (void)testInitWithoutFileHashGivesZeroFileHash {
    Track *track = [self trackWithSize:4096];

    XCTAssertEqual(track.fileHash, 0UL);
    XCTAssertEqualObjects(track, [self trackWithFileHash:0]);
}

- (void)testInitWithDisplayNameKeepsFileHash {
    Track *track = [[Track alloc] initWithDisplayName:@"Song.mp3"
                                        pathExtension:@"mp3"
                                                 path:@"/Music/Artist/Album/Song.mp3"
                                           folderName:@"Album"
                                     parentFolderName:@"Artist"
                                                 size:4096
                                             fileHash:0xCE7D19A5418FB365];

    XCTAssertEqual(track.fileHash, 0xCE7D19A5418FB365);
    XCTAssertEqualObjects(track, [self trackWithFileHash:0xCE7D19A5418FB365]);
}

- (void)testInitWithDisplayNameRejectsNonMusicExtension {
    Track *track = [[Track alloc] initWithDisplayName:@"cover.jpg"
                                        pathExtension:@"jpg"
                                                 path:@"/Music/cover.jpg"
                                           folderName:nil
                                     parentFolderName:nil
                                                 size:4096
                                             fileHash:0];

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

- (void)testTracksWithDifferentFileHashesAreNotEqual {
    Track *first = [self trackWithFileHash:1];
    Track *second = [self trackWithFileHash:2];

    XCTAssertNotEqualObjects(first, second);
    XCTAssertNotEqual(first.hash, second.hash);
}

- (void)testTracksWithSameFileHashAreEqual {
    XCTAssertEqualObjects([self trackWithFileHash:1], [self trackWithFileHash:1]);
    XCTAssertEqual([self trackWithFileHash:1].hash, [self trackWithFileHash:1].hash);
}

- (void)testMusicFileExtensionsAreCaseInsensitive {
    XCTAssertTrue([Track isMusicFileExtension:@"mp3"]);
    XCTAssertTrue([Track isMusicFileExtension:@"M4A"]);
    XCTAssertFalse([Track isMusicFileExtension:@"flac"]);
    XCTAssertFalse([Track isMusicFileExtension:@""]);
}

@end
