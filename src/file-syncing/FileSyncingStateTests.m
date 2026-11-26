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


@end
