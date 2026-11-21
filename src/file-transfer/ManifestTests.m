#import <XCTest/XCTest.h>

#import "CSV.h"
#import "Manifest.h"
#import "TrackMetadata.h"


static TrackMetadata *make_metadata(NSString *relativePath,
    unsigned long long size, time_t mtime, NSUInteger fileHash)
{
    return [[TrackMetadata alloc] initWithRelativePath:relativePath
                                                  size:size
                                                 mtime:mtime
                                              fileHash:fileHash];
}


static Manifest *make_manifest(NSArray<TrackMetadata *> *metadata)
{
    return [[Manifest alloc] initWithTrackMetadata:metadata];
}


static NSString *csv_text(Manifest *manifest)
{
    return [[NSString alloc] initWithData:manifest.csv
                                 encoding:NSUTF8StringEncoding];
}


static NSData *csv_data(NSString *csv)
{
    return [csv dataUsingEncoding:NSUTF8StringEncoding];
}


static Manifest *_Nullable manifest_from_csv(NSString *csv)
{
    return [[Manifest alloc] initWithCSV:csv_data(csv) error:NULL];
}


static NSError *error_from_csv(NSString *csv)
{
    NSError *error = nil;
    Manifest *manifest = [[Manifest alloc] initWithCSV:csv_data(csv)
                                                 error:&error];
    return manifest ? nil : error;
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


- (void)testFindsMetadataByTrackRelativePath;
{
    TrackMetadata *song =
        make_metadata(@"Artist/Album/Song.mp3", 5, 1700000000, 7);
    TrackMetadata *tune = make_metadata(@"Tune.m4a", 9, 0, 11);

    Manifest *manifest = make_manifest(@[song, tune]);

    XCTAssertEqual(manifest.trackCount, 2UL);
    XCTAssertEqual(
        [manifest metadataForRelativePath:@"Artist/Album/Song.mp3"], song);
    XCTAssertEqual([manifest metadataForRelativePath:@"Tune.m4a"], tune);
}


- (void)testFindsNothingForUnknownOrAbsolutePaths;
{
    Manifest *manifest =
        make_manifest(@[make_metadata(@"Artist/Album/Song.mp3", 5, 0, 7)]);

    XCTAssertNil([manifest metadataForRelativePath:@"Artist/Album/Other.mp3"]);
    XCTAssertNil(
        [manifest metadataForRelativePath:@"/snapshot/Artist/Album/Song.mp3"]);
    XCTAssertNil([manifest metadataForRelativePath:@""]);
}


- (void)testCSVHasOneRecordPerTrackSortedByPathBytes;
{
    Manifest *manifest = make_manifest(@[
        make_metadata(@"b/Song.mp3", 2, 0, 20),
        make_metadata(@"é/Song.mp3", 3, 0, 30),
        make_metadata(@"B/Song.mp3", 1, 0, 10),
    ]);

    XCTAssertEqualObjects(csv_text(manifest),
        @"path,size,hash\r\n"
        @"B/Song.mp3,1,10\r\n"
        @"b/Song.mp3,2,20\r\n"
        @"é/Song.mp3,3,30\r\n");
}


- (void)testCSVQuotesPathsThatContainCommas;
{
    Manifest *manifest =
        make_manifest(@[make_metadata(@"Piaf, Edith/Song.mp3", 5, 0, 7)]);

    XCTAssertEqualObjects(csv_text(manifest),
        @"path,size,hash\r\n\"Piaf, Edith/Song.mp3\",5,7\r\n");
}


- (void)testCSVRoundTripKeepsPathsSizesAndHashes;
{
    Manifest *original = make_manifest(@[
        make_metadata(@"Artist/Album/Song.mp3", 5, 1700000000, 7),
        make_metadata(@"Tune.m4a", 9, 0, 11),
    ]);

    Manifest *manifest = [[Manifest alloc] initWithCSV:original.csv error:NULL];

    XCTAssertEqual(manifest.trackCount, 2UL);
    TrackMetadata *song =
        [manifest metadataForRelativePath:@"Artist/Album/Song.mp3"];
    XCTAssertEqualObjects(song.relativePath, @"Artist/Album/Song.mp3");
    XCTAssertEqual(song.size, 5ULL);
    XCTAssertEqual(song.fileHash, 7UL);
    XCTAssertEqual([manifest metadataForRelativePath:@"Tune.m4a"].size, 9ULL);
    XCTAssertEqualObjects(manifest.csv, original.csv);
}


- (void)testManifestFromCSVHasZeroMtimes;
{
    Manifest *manifest =
        manifest_from_csv(@"path,size,hash\r\nSong.mp3,5,7\r\n");

    XCTAssertEqual([manifest metadataForRelativePath:@"Song.mp3"].mtime, 0L);
}


- (void)testHeaderOnlyCSVGivesAnEmptyManifest;
{
    Manifest *manifest = manifest_from_csv(@"path,size,hash\r\n");

    XCTAssertNotNil(manifest);
    XCTAssertEqual(manifest.trackCount, 0UL);
}


- (void)testUnsortedCSVWithLineFeedsIsRegeneratedInCanonicalForm;
{
    Manifest *manifest =
        manifest_from_csv(@"path,size,hash\nb.mp3,2,20\na.mp3,1,10\n");

    XCTAssertEqualObjects(
        csv_text(manifest), @"path,size,hash\r\na.mp3,1,10\r\nb.mp3,2,20\r\n");
}


- (void)testReadsQuotedPathsThatContainCommas;
{
    Manifest *manifest = manifest_from_csv(
        @"path,size,hash\r\n\"Piaf, Edith/Song.mp3\",5,7\r\n");

    XCTAssertEqual(
        [manifest metadataForRelativePath:@"Piaf, Edith/Song.mp3"].size, 5ULL);
}


- (void)testReadsTheLargestHash;
{
    Manifest *manifest = manifest_from_csv(
        @"path,size,hash\r\nSong.mp3,5,18446744073709551615\r\n");

    XCTAssertEqual([manifest metadataForRelativePath:@"Song.mp3"].fileHash,
        (NSUInteger)UINT64_MAX);
}


- (void)testRejectsCSVWithoutTheManifestHeader;
{
    for (NSString *csv in @[
             @"",
             @"path\r\nSong.mp3\r\n",
             @"path,size,mtime\r\nSong.mp3,5,7\r\n",
             @"Song.mp3,5,7\r\n",
             @"path,size,hash,extra\r\n",
         ]) {
        NSError *error = error_from_csv(csv);

        XCTAssertEqualObjects(error.domain, ManifestErrorDomain, @"%@", csv);
        XCTAssertEqual(error.code, ManifestErrorCodeInvalidHeader, @"%@", csv);
    }
}


- (void)testPassesOnCSVParseErrors;
{
    NSError *error = error_from_csv(@"path,size,hash\r\nSong.mp3,5\r\n");

    XCTAssertEqualObjects(error.domain, CSVErrorDomain);
    XCTAssertEqual(error.code, CSVErrorCodeInconsistentFieldCount);
}


- (void)testRejectsSizesThatAreNotUnsignedDecimalIntegers;
{
    for (NSString *size in @[
             @"", @"abc", @"-5", @"+5", @" 5", @"5 ", @"5.0", @"0x5",
             @"18446744073709551616"
         ]) {
        NSError *error = error_from_csv([NSString
            stringWithFormat:@"path,size,hash\r\nSong.mp3,%@,7\r\n", size]);

        XCTAssertEqualObjects(error.domain, ManifestErrorDomain, @"%@", size);
        XCTAssertEqual(error.code, ManifestErrorCodeInvalidSize, @"%@", size);
    }
}


- (void)testRejectsHashesThatAreNotUnsignedDecimalIntegers;
{
    for (NSString *hash in @[
             @"", @"abc", @"-7", @"+7", @" 7", @"7 ", @"7.0", @"0x7",
             @"18446744073709551616"
         ]) {
        NSError *error = error_from_csv([NSString
            stringWithFormat:@"path,size,hash\r\nSong.mp3,5,%@\r\n", hash]);

        XCTAssertEqualObjects(error.domain, ManifestErrorDomain, @"%@", hash);
        XCTAssertEqual(error.code, ManifestErrorCodeInvalidHash, @"%@", hash);
    }
}


- (void)testInvalidRecordErrorNamesTheRecord;
{
    NSError *error =
        error_from_csv(@"path,size,hash\r\na.mp3,1,10\r\nb.mp3,oops,20\r\n");

    XCTAssertEqualObjects(
        error.localizedDescription, @"Invalid size in record 3");
}


- (void)testTracksMissingFromReturnsTracksOnlyInTheReceiver;
{
    TrackMetadata *shared = make_metadata(@"shared.mp3", 1, 0, 10);
    TrackMetadata *onlyB = make_metadata(@"b.mp3", 2, 0, 20);
    TrackMetadata *onlyUpperB = make_metadata(@"B.mp3", 3, 0, 30);
    Manifest *manifest = make_manifest(@[shared, onlyB, onlyUpperB]);
    Manifest *other = make_manifest(@[
        make_metadata(@"shared.mp3", 1, 0, 99),
        make_metadata(@"other.mp3", 4, 0, 40),
    ]);

    NSArray<TrackMetadata *> *missing = [manifest tracksMissingFrom:other];

    XCTAssertEqual(missing.count, 2UL);
    XCTAssertEqual(missing[0], onlyUpperB);
    XCTAssertEqual(missing[1], onlyB);
}


- (void)testNoTracksAreMissingFromAnIdenticalManifest;
{
    Manifest *manifest = make_manifest(@[make_metadata(@"a.mp3", 1, 0, 10)]);
    Manifest *other = make_manifest(@[make_metadata(@"a.mp3", 1, 0, 10)]);

    XCTAssertEqualObjects([manifest tracksMissingFrom:other], @[]);
}


- (void)testAllTracksAreMissingFromAnEmptyManifest;
{
    TrackMetadata *track = make_metadata(@"a.mp3", 1, 0, 10);
    Manifest *manifest = make_manifest(@[track]);

    XCTAssertEqualObjects(
        [manifest tracksMissingFrom:make_manifest(@[])], @[track]);
    XCTAssertEqualObjects([make_manifest(@[]) tracksMissingFrom:manifest], @[]);
}


- (void)testTracksChangedInReturnsSharedTracksWithDifferentHashes;
{
    TrackMetadata *changedB = make_metadata(@"b.mp3", 2, 0, 20);
    TrackMetadata *changedA = make_metadata(@"a.mp3", 1, 0, 10);
    Manifest *manifest = make_manifest(@[
        changedB,
        changedA,
        make_metadata(@"same.mp3", 3, 0, 30),
        make_metadata(@"resized.mp3", 4, 0, 40),
        make_metadata(@"only-here.mp3", 5, 0, 50),
    ]);
    Manifest *other = make_manifest(@[
        make_metadata(@"a.mp3", 1, 0, 11),
        make_metadata(@"b.mp3", 2, 0, 21),
        make_metadata(@"same.mp3", 3, 0, 30),
        make_metadata(@"resized.mp3", 44, 0, 40),
        make_metadata(@"only-there.mp3", 6, 0, 60),
    ]);

    NSArray<TrackMetadata *> *changed = [manifest tracksChangedIn:other];

    XCTAssertEqual(changed.count, 2UL);
    XCTAssertEqual(changed[0], changedA);
    XCTAssertEqual(changed[1], changedB);
}


- (void)testTracksChangedInReturnsTheReceiversMetadata;
{
    TrackMetadata *mine = make_metadata(@"a.mp3", 1, 0, 10);
    TrackMetadata *theirs = make_metadata(@"a.mp3", 2, 0, 11);
    Manifest *manifest = make_manifest(@[mine]);
    Manifest *other = make_manifest(@[theirs]);

    XCTAssertEqual([manifest tracksChangedIn:other].firstObject, mine);
    XCTAssertEqual([other tracksChangedIn:manifest].firstObject, theirs);
}


- (void)testZeroHashesAreComparedLikeAnyOtherHash;
{
    Manifest *manifest = make_manifest(@[
        make_metadata(@"both-zero.mp3", 1, 0, 0),
        make_metadata(@"one-zero.mp3", 2, 0, 0),
    ]);
    Manifest *other = make_manifest(@[
        make_metadata(@"both-zero.mp3", 1, 0, 0),
        make_metadata(@"one-zero.mp3", 2, 0, 20),
    ]);

    NSArray<TrackMetadata *> *changed = [manifest tracksChangedIn:other];

    XCTAssertEqual(changed.count, 1UL);
    XCTAssertEqualObjects(changed[0].relativePath, @"one-zero.mp3");
}


@end
