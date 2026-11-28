#import <XCTest/XCTest.h>

#import "FileSyncingState.h"
#import "FileSystemFake.h"
#import "Manifest.h"
#import "TrackMetadata.h"


static NSString *const emptyManifestCSV = @"path,size,hash\r\n";


static NSURL *local_manifest_path(void)
{
    return [NSURL fileURLWithPath:@"/Working/manifest.csv"];
}


static FileSystemFake *file_system_with_local_manifest(NSString *csv)
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    [fileSystem addPath:local_manifest_path().path
               contents:[csv dataUsingEncoding:NSUTF8StringEncoding]];
    return fileSystem;
}


static FileSyncingState *state_with_file_system(FileSystemFake *fileSystem)
{
    return [[FileSyncingState alloc]
        initWithLocalManifestPath:local_manifest_path()
                    andFileSystem:fileSystem];
}


static Manifest *manifest_with_track(NSString *relativePath)
{
    TrackMetadata *metadata =
        [[TrackMetadata alloc] initWithRelativePath:relativePath
                                               size:5
                                           fileHash:7];
    return [[Manifest alloc] initWithTrackMetadata:@[metadata]];
}


static const unsigned long long megabyte = 1024ULL * 1024;
static const NSUInteger serverFileHash = 7;


static Manifest *server_manifest_with_sizes(
    NSDictionary<NSString *, NSNumber *> *sizesByPath
)
{
    NSMutableArray<TrackMetadata *> *metadata = [NSMutableArray array];
    for (NSString *relativePath in sizesByPath) {
        unsigned long long size =
            sizesByPath[relativePath].unsignedLongLongValue;
        [metadata addObject:[[TrackMetadata alloc]
                                initWithRelativePath:relativePath
                                                size:size
                                            fileHash:serverFileHash]];
    }
    return [[Manifest alloc] initWithTrackMetadata:metadata];
}


static NSString *csv_text(Manifest *manifest)
{
    return [[NSString alloc] initWithData:manifest.csv
                                 encoding:NSUTF8StringEncoding];
}


@interface FileSyncingStateTests : XCTestCase
@end


@implementation FileSyncingStateTests


#pragma mark - initWithLocalManifestPath:andFileSystem: tests


- (void)testInitReadsLocalManifestFromCSVPath;
{
    NSString *csv = @"path,size,hash\r\n"
                    @"Artist/Album/Song.mp3,5,7\r\n"
                    @"Tune.m4a,9,11\r\n";

    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(csv));

    XCTAssertEqualObjects(csv_text(state.localManifest), csv);
}


- (void)testInitStartsWithEmptyLocalManifestWhenCSVFileIsMissing;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);

    XCTAssertEqualObjects(csv_text(state.localManifest), emptyManifestCSV);
}


- (void)testInitStartsWithEmptyLocalManifestWhenCSVFileIsUnreadable;
{
    FileSystemFake *fileSystem =
        file_system_with_local_manifest(@"path,size,hash\r\nTune.m4a,9,11\r\n");
    fileSystem.unreadableFiles =
        [NSSet setWithObject:local_manifest_path().path];

    FileSyncingState *state = state_with_file_system(fileSystem);

    XCTAssertEqualObjects(csv_text(state.localManifest), emptyManifestCSV);
}


- (void)testInitStartsWithEmptyLocalManifestWhenCSVIsInvalid;
{
    FileSyncingState *state = state_with_file_system(
        file_system_with_local_manifest(@"not,a,manifest\r\nTune.m4a,9,11\r\n")
    );

    XCTAssertEqualObjects(csv_text(state.localManifest), emptyManifestCSV);
}


- (void)testInitStartsWithoutServerManifest;
{
    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(emptyManifestCSV)
        );

    XCTAssertNil(state.serverManifest);
}


- (void)testInitStartsWithEmptyTarballs;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);

    XCTAssertEqualObjects(state.tarballs, @{});
}


#pragma mark - updateWithServerManifest: tests


- (void)testUpdateKeepsServerManifest;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);
    Manifest *serverManifest = manifest_with_track(@"Tune.m4a");

    [state updateWithServerManifest:serverManifest];

    XCTAssertEqual(state.serverManifest, serverManifest);
}


- (void)testUpdateReplacesEarlierServerManifest;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);
    Manifest *laterServerManifest = manifest_with_track(@"Later.m4a");
    [state updateWithServerManifest:manifest_with_track(@"Earlier.m4a")];

    [state updateWithServerManifest:laterServerManifest];

    XCTAssertEqual(state.serverManifest, laterServerManifest);
}


- (void)testUpdateLeavesLocalManifestUnchanged;
{
    NSString *csv = @"path,size,hash\r\nLocal.m4a,9,11\r\n";
    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(csv));

    [state updateWithServerManifest:manifest_with_track(@"Server.m4a")];

    XCTAssertEqualObjects(csv_text(state.localManifest), csv);
}


- (void)testUpdateKeepsServerMetadataForChangedTrack;
{
    FileSyncingState *state = state_with_file_system(
        file_system_with_local_manifest(@"path,size,hash\r\nTune.m4a,9,11\r\n")
    );

    [state
        updateWithServerManifest:server_manifest_with_sizes(@{@"Tune.m4a": @20}
                                 )];

    XCTAssertEqual(state.changedTracks.count, 1UL);
    XCTAssertEqual(state.changedTracks.firstObject.size, 20ULL);
    XCTAssertEqual(state.changedTracks.firstObject.fileHash, serverFileHash);
}


#pragma mark - tarballs tests


- (void)testTarballsAreEmptyWhenNothingToDownload;
{
    NSString *csv = @"path,size,hash\r\nSame.m4a,5,7\r\nRemoved.m4a,9,11\r\n";
    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(csv));

    [state updateWithServerManifest:manifest_with_track(@"Same.m4a")];

    XCTAssertEqualObjects(state.tarballs, @{});
}


- (void)testTarballsPutSmallAddedTracksInOneTarballSortedByPath;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);

    [state updateWithServerManifest:server_manifest_with_sizes(@{
               @"C.m4a": @5,
               @"A.m4a": @5,
               @"B.m4a": @5,
           })];

    XCTAssertEqualObjects(
        state.tarballs, (@{@1: @[@[@"A.m4a"], @[@"B.m4a"], @[@"C.m4a"]]})
    );
}


- (void)testTarballsMergeAddedAndChangedTracksSortedByPath;
{
    NSString *csv = @"path,size,hash\r\nB.m4a,9,11\r\nD.m4a,9,11\r\n";
    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(csv));

    [state updateWithServerManifest:server_manifest_with_sizes(@{
               @"A.m4a": @5,
               @"B.m4a": @5,
               @"C.m4a": @5,
               @"D.m4a": @5,
           })];

    XCTAssertEqualObjects(
        state.tarballs,
        (@{@1: @[@[@"A.m4a"], @[@"B.m4a"], @[@"C.m4a"], @[@"D.m4a"]]})
    );
}


- (void)testTarballsLeaveOutRemovedTracks;
{
    NSString *csv = @"path,size,hash\r\nRemoved.m4a,9,11\r\n";
    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(csv));

    [state updateWithServerManifest:manifest_with_track(@"Added.m4a")];

    XCTAssertEqualObjects(state.tarballs, (@{@1: @[@[@"Added.m4a"]]}));
}


- (void)testTarballsKeepTracksTotallingExactlyTheLimitTogether;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);

    [state updateWithServerManifest:server_manifest_with_sizes(@{
               @"A.m4a": @(60 * megabyte),
               @"B.m4a": @(40 * megabyte),
           })];

    XCTAssertEqualObjects(state.tarballs, (@{@1: @[@[@"A.m4a"], @[@"B.m4a"]]}));
}


- (void)testTarballsStartNewTarballWhenTotalWouldExceedTheLimit;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);

    [state updateWithServerManifest:server_manifest_with_sizes(@{
               @"A.m4a": @(60 * megabyte),
               @"B.m4a": @(40 * megabyte + 1),
               @"C.m4a": @(10 * megabyte),
           })];

    XCTAssertEqualObjects(
        state.tarballs, (@{@1: @[@[@"A.m4a"]], @2: @[@[@"B.m4a"], @[@"C.m4a"]]})
    );
}


- (void)testTarballsPutTrackOverTheLimitAlone;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);

    [state updateWithServerManifest:server_manifest_with_sizes(@{
               @"A.m4a": @5,
               @"B.m4a": @(150 * megabyte),
               @"C.m4a": @5,
           })];

    XCTAssertEqualObjects(
        state.tarballs,
        (@{@1: @[@[@"A.m4a"]], @2: @[@[@"B.m4a"]], @3: @[@[@"C.m4a"]]})
    );
}


- (void)testTarballsSizeChangedTrackFromServerManifest;
{
    NSString *csv = @"path,size,hash\r\nB.m4a,9,11\r\n";
    FileSyncingState *state =
        state_with_file_system(file_system_with_local_manifest(csv));

    [state updateWithServerManifest:server_manifest_with_sizes(@{
               @"A.m4a": @(60 * megabyte),
               @"B.m4a": @(60 * megabyte),
           })];

    XCTAssertEqualObjects(
        state.tarballs, (@{@1: @[@[@"A.m4a"]], @2: @[@[@"B.m4a"]]})
    );
}


- (void)testTarballsAreReplacedByLaterUpdate;
{
    FileSyncingState *state = state_with_file_system([FileSystemFake new]);
    [state updateWithServerManifest:manifest_with_track(@"Earlier.m4a")];

    [state updateWithServerManifest:manifest_with_track(@"Later.m4a")];

    XCTAssertEqualObjects(state.tarballs, (@{@1: @[@[@"Later.m4a"]]}));
}


@end
