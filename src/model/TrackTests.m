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
}

- (void)testInitWithoutFileHashGivesZeroFileHash {
    Track *track = [self trackWithSize:4096];

    XCTAssertEqual(track.size, 4096ULL);
    XCTAssertEqual(track.fileHash, 0UL);
}

- (void)testInitWithDisplayNameKeepsEveryProperty {
    Track *track = [[Track alloc] initWithDisplayName:@"Song.mp3"
                                        pathExtension:@"mp3"
                                                 path:@"/Music/Artist/Album/Song.mp3"
                                           folderName:@"Album"
                                     parentFolderName:@"Artist"
                                                 size:4096
                                             fileHash:0xCE7D19A5418FB365];

    XCTAssertEqualObjects(track.trackName, @"Song");
    XCTAssertEqualObjects(track.albumName, @"Album");
    XCTAssertEqualObjects(track.artistName, @"Artist");
    XCTAssertEqualObjects(track.path, @"/Music/Artist/Album/Song.mp3");
    XCTAssertEqual(track.size, 4096ULL);
    XCTAssertEqual(track.fileHash, 0xCE7D19A5418FB365);
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

- (void)testTracksWithSamePathAreEqualWhateverElseDiffers {
    Track *loaded = [[Track alloc] initWithTrackName:@"Song"
                                           albumName:@"Album"
                                          artistName:@"Artist"
                                                path:@"/Music/Artist/Album/Song.mp3"
                                                size:4096
                                            fileHash:0xCE7D19A5418FB365];
    Track *bare = [[Track alloc] initWithTrackName:@"Other"
                                         albumName:Track.noAlbum
                                        artistName:Track.noArtist
                                              path:@"/Music/Artist/Album/Song.mp3"];

    XCTAssertEqualObjects(loaded, bare);
    XCTAssertEqual(loaded.hash, bare.hash);
}

- (void)testTracksWithDifferentPathsAreNotEqual {
    Track *first = [[Track alloc] initWithTrackName:@"Song"
                                          albumName:@"Album"
                                         artistName:@"Artist"
                                               path:@"/Music/Artist/Album/Song.mp3"
                                               size:4096
                                           fileHash:1];
    Track *second = [[Track alloc] initWithTrackName:@"Song"
                                           albumName:@"Album"
                                          artistName:@"Artist"
                                                path:@"/Music/Artist/Album/Song.m4a"
                                                size:4096
                                            fileHash:1];

    XCTAssertNotEqualObjects(first, second);
    XCTAssertNotEqual(first.hash, second.hash);
}

- (void)testTrackIsNotEqualToItsPath {
    XCTAssertNotEqualObjects([self trackWithSize:4096], @"/Music/Artist/Album/Song.mp3");
}

- (void)testSetHoldsOneTrackPerPath {
    NSSet<Track *> *tracks = [NSSet setWithArray:@[
        [self trackWithSize:0],
        [self trackWithSize:4096],
    ]];

    XCTAssertEqual(tracks.count, 1UL);
}

- (void)testMusicFileExtensionsAreCaseInsensitive {
    XCTAssertTrue([Track isMusicFileExtension:@"mp3"]);
    XCTAssertTrue([Track isMusicFileExtension:@"M4A"]);
    XCTAssertFalse([Track isMusicFileExtension:@"flac"]);
    XCTAssertFalse([Track isMusicFileExtension:@""]);
}

@end
