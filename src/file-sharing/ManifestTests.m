#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "Manifest.h"
#import "TrackMetadata.h"


static TrackMetadata *make_metadata(
    NSString *path, unsigned long long size, time_t mtime, NSUInteger fileHash)
{
    Track *track = [[Track alloc] initWithTrackName:@"Track"
                                          albumName:@"Album"
                                         artistName:@"Artist"
                                               path:path];
    return [[TrackMetadata alloc] initWithTrack:track
                                           size:size
                                          mtime:mtime
                                       fileHash:fileHash];
}


static Manifest *make_manifest(NSArray<TrackMetadata *> *metadata)
{
    return [[Manifest alloc]
        initWithTrackMetadata:metadata
        musicLibraryDirectory:[NSURL fileURLWithPath:@"/snapshot"
                                         isDirectory:YES]];
}


static NSString *csv_text(Manifest *manifest)
{
    return [[NSString alloc] initWithData:manifest.csv
                                 encoding:NSUTF8StringEncoding];
}


@interface ManifestTests : XCTestCase
@end


@implementation ManifestTests


- (void)testEmptyManifestHasOnlyTheHeaderRecord;
{
    Manifest *manifest = make_manifest(@[]);

    XCTAssertEqual(manifest.trackCount, 0UL);
    XCTAssertEqualObjects(csv_text(manifest), @"path,size,hash\r\n");
}


- (void)testKeepsTheMusicLibraryDirectory;
{
    Manifest *manifest = make_manifest(@[]);

    XCTAssertEqualObjects(manifest.musicLibraryDirectory.path, @"/snapshot");
}


- (void)testFindsMetadataByTrackRelativePath;
{
    TrackMetadata *song =
        make_metadata(@"/snapshot/Artist/Album/Song.mp3", 5, 1700000000, 7);
    TrackMetadata *tune = make_metadata(@"/snapshot/Tune.m4a", 9, 0, 11);

    Manifest *manifest = make_manifest(@[song, tune]);

    XCTAssertEqual(manifest.trackCount, 2UL);
    XCTAssertEqual(
        [manifest metadataForRelativePath:@"Artist/Album/Song.mp3"], song);
    XCTAssertEqual([manifest metadataForRelativePath:@"Tune.m4a"], tune);
}


- (void)testFindsNothingForUnknownOrAbsolutePaths;
{
    Manifest *manifest = make_manifest(
        @[make_metadata(@"/snapshot/Artist/Album/Song.mp3", 5, 0, 7)]);

    XCTAssertNil([manifest metadataForRelativePath:@"Artist/Album/Other.mp3"]);
    XCTAssertNil(
        [manifest metadataForRelativePath:@"/snapshot/Artist/Album/Song.mp3"]);
    XCTAssertNil([manifest metadataForRelativePath:@""]);
}


- (void)testCSVHasOneRecordPerTrackSortedByPathBytes;
{
    Manifest *manifest = make_manifest(@[
        make_metadata(@"/snapshot/b/Song.mp3", 2, 0, 20),
        make_metadata(@"/snapshot/é/Song.mp3", 3, 0, 30),
        make_metadata(@"/snapshot/B/Song.mp3", 1, 0, 10),
    ]);

    XCTAssertEqualObjects(csv_text(manifest),
        @"path,size,hash\r\n"
        @"B/Song.mp3,1,10\r\n"
        @"b/Song.mp3,2,20\r\n"
        @"é/Song.mp3,3,30\r\n");
}


- (void)testCSVQuotesPathsThatContainCommas;
{
    Manifest *manifest = make_manifest(
        @[make_metadata(@"/snapshot/Piaf, Edith/Song.mp3", 5, 0, 7)]);

    XCTAssertEqualObjects(csv_text(manifest),
        @"path,size,hash\r\n\"Piaf, Edith/Song.mp3\",5,7\r\n");
}


@end


#endif
