#import <XCTest/XCTest.h>

#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"
#import "LoadTrackMetadata.h"

@interface LoadTrackMetadataTests : XCTestCase
@end

static const NSUInteger emptyFileHash = 0x2D06800538D394C2;
static const NSUInteger foxFileHash = 0xCE7D19A5418FB365;

static NSData *foxContents(void) {
    return [@"The quick brown fox jumps over the lazy dog" dataUsingEncoding:NSUTF8StringEncoding];
}

static Track *track(NSString *path) {
    return [[Track alloc] initWithTrackName:path.lastPathComponent.stringByDeletingPathExtension
                                  albumName:Track.noAlbum
                                 artistName:Track.noArtist
                                       path:path];
}

static NSString *metadata(NSString *path, unsigned long long size, NSUInteger fileHash) {
    return [[TrackMetadata alloc] initWithTrack:track(path) size:size fileHash:fileHash].description;
}

static NSArray<NSString *> *descriptions(NSArray<TrackMetadata *> *metadata) {
    return [metadata valueForKey:@"description"];
}

@implementation LoadTrackMetadataTests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (void)testNoTracksGiveNoMetadataAndNoErrors {
    NSArray<NSError *> *errors;

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(@[], [[FileSystemFake alloc] init], &errors);

    XCTAssertEqualObjects(loaded, @[]);
    XCTAssertEqualObjects(errors, @[]);
}

- (void)testMetadataKeepsItsTrack {
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Song.mp3" size:4096];
    Track *song = track(@"/Music/Song.mp3");

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(@[song], fileSystem, NULL);

    XCTAssertEqual(loaded.count, 1UL);
    XCTAssertEqual(loaded[0].track, song);
}

- (void)testTrackSizeIsRead {
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Song.mp3" size:4096];
    [fileSystem addPath:@"/Music/Empty.m4a" size:0];
    NSArray<Track *> *tracks = @[track(@"/Music/Empty.m4a"), track(@"/Music/Song.mp3")];
    NSArray<NSError *> *errors;

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(tracks, fileSystem, &errors);

    XCTAssertEqual(loaded.count, 2UL);
    XCTAssertEqual(loaded[0].size, 0ULL);
    XCTAssertEqual(loaded[1].size, 4096ULL);
    XCTAssertEqual(errors.count, 0UL);
}

- (void)testTrackSizeAndHashAreBothRead {
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Song.mp3" contents:foxContents()];
    [fileSystem addPath:@"/Music/Empty.m4a" contents:[NSData data]];
    NSArray<Track *> *tracks = @[track(@"/Music/Empty.m4a"), track(@"/Music/Song.mp3")];
    NSArray<NSError *> *errors;

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(tracks, fileSystem, &errors);

    XCTAssertEqualObjects(descriptions(loaded), (@[
        metadata(@"/Music/Empty.m4a", 0, emptyFileHash),
        metadata(@"/Music/Song.mp3", 43, foxFileHash),
    ]));
    XCTAssertEqual(errors.count, 0UL);
}

- (void)testMetadataFollowsTheOrderOfTheTracks {
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/A.mp3" size:1];
    [fileSystem addPath:@"/Music/B.mp3" size:2];
    [fileSystem addPath:@"/Music/C.mp3" size:3];
    NSArray<Track *> *tracks = @[track(@"/Music/C.mp3"), track(@"/Music/A.mp3"), track(@"/Music/B.mp3")];

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(tracks, fileSystem, NULL);

    XCTAssertEqualObjects([loaded valueForKeyPath:@"track.path"],
        (@[@"/Music/C.mp3", @"/Music/A.mp3", @"/Music/B.mp3"]));
}

- (void)testUnsizeableTrackIsSkippedAndReportsFailure {
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Bad.mp3" contents:foxContents()];
    [fileSystem addPath:@"/Music/Good.mp3" contents:foxContents()];
    fileSystem.unsizeableFiles = [NSSet setWithObject:@"/Music/Bad.mp3"];
    NSArray<Track *> *tracks = @[track(@"/Music/Bad.mp3"), track(@"/Music/Good.mp3")];
    NSArray<NSError *> *errors;

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(tracks, fileSystem, &errors);

    XCTAssertEqualObjects(descriptions(loaded), (@[
        metadata(@"/Music/Good.mp3", 43, foxFileHash),
    ]));
    XCTAssertEqual(errors.count, 1UL);
    XCTAssertEqualObjects(fileSystemFakeErrorPaths(errors), @[@"/Music/Bad.mp3"]);
}

- (void)testUnhashableTrackKeepsZeroHashAndReportsFailure {
    FileSystemFake *fileSystem = [[FileSystemFake alloc] init];
    [fileSystem addPath:@"/Music/Bad.mp3" contents:foxContents()];
    [fileSystem addPath:@"/Music/Good.mp3" contents:foxContents()];
    fileSystem.unreadableFiles = [NSSet setWithObject:@"/Music/Bad.mp3"];
    NSArray<Track *> *tracks = @[track(@"/Music/Bad.mp3"), track(@"/Music/Good.mp3")];
    NSArray<NSError *> *errors;

    NSArray<TrackMetadata *> *loaded = loadTrackMetadata(tracks, fileSystem, &errors);

    XCTAssertEqualObjects(descriptions(loaded), (@[
        metadata(@"/Music/Bad.mp3", 43, 0),
        metadata(@"/Music/Good.mp3", 43, foxFileHash),
    ]));
    XCTAssertEqual(errors.count, 1UL);
    XCTAssertEqualObjects(fileSystemFakeErrorPaths(errors), @[@"/Music/Bad.mp3"]);
}

@end
