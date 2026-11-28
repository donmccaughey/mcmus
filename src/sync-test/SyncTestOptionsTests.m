#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "SyncTestOptions.h"


@interface SyncTestOptionsTests : XCTestCase
@end


@implementation SyncTestOptionsTests {
    NSURL *_currentDirectoryURL;
}


- (void)setUp;
{
    [super setUp];
    _currentDirectoryURL = [NSURL fileURLWithPath:@"/Current/Dir"
                                      isDirectory:YES];
}


- (nullable SyncTestOptions *)parse:(NSArray<NSString *> *)arguments
                              error:(NSError **)error;
{
    NSArray<NSString *> *withProgramName =
        [@[@"sync-test"] arrayByAddingObjectsFromArray:arguments];
    return [SyncTestOptions optionsWithArguments:withProgramName
                             currentDirectoryURL:_currentDirectoryURL
                                           error:error];
}


- (void)assertParsing:(NSArray<NSString *> *)arguments
       failsWithError:(NSString *)description;
{
    NSError *error = nil;
    SyncTestOptions *options = [self parse:arguments error:&error];

    XCTAssertNil(options);
    XCTAssertEqualObjects(error.localizedDescription, description);
}


- (void)testAbsoluteMusicDirIsUsedAsGiven;
{
    SyncTestOptions *options = [self parse:@[@"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
    XCTAssertTrue(options.musicDirectoryURL.hasDirectoryPath);
}


- (void)testRelativeMusicDirIsResolvedAgainstCurrentDirectory;
{
    SyncTestOptions *options = [self parse:@[@"some/music"] error:NULL];

    XCTAssertEqualObjects(
        options.musicDirectoryURL.path, @"/Current/Dir/some/music"
    );
}


- (void)testWorkingDirectoryDefaultsToCurrentDirectory;
{
    SyncTestOptions *options = [self parse:@[@"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Current/Dir");
}


- (void)testAbsoluteWorkdirIsUsedAsGiven;
{
    SyncTestOptions *options =
        [self parse:@[@"--workdir=/Work/Dir", @"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Work/Dir");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
}


- (void)testRelativeWorkdirIsResolvedAgainstCurrentDirectory;
{
    SyncTestOptions *options =
        [self parse:@[@"--workdir=work/dir", @"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(
        options.workingDirectoryURL.path, @"/Current/Dir/work/dir"
    );
}


- (void)testWorkdirMayFollowMusicDir;
{
    SyncTestOptions *options =
        [self parse:@[@"/Some/Music", @"--workdir=/Work/Dir"] error:NULL];

    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Work/Dir");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
}


- (void)testManifestDefaultsToManifestCSVInCurrentDirectory;
{
    SyncTestOptions *options = [self parse:@[@"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(
        options.manifestURL.path, @"/Current/Dir/manifest.csv"
    );
    XCTAssertFalse(options.manifestURL.hasDirectoryPath);
}


- (void)testManifestDefaultsToManifestCSVInWorkdir;
{
    SyncTestOptions *options =
        [self parse:@[@"--workdir=/Work/Dir", @"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.manifestURL.path, @"/Work/Dir/manifest.csv");
}


- (void)testAbsoluteManifestIsUsedAsGiven;
{
    SyncTestOptions *options = [self parse:@[
        @"--workdir=/Work/Dir",
        @"--manifest=/Some/old.csv",
        @"/Some/Music"
    ]
                                     error:NULL];

    XCTAssertEqualObjects(options.manifestURL.path, @"/Some/old.csv");
    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Work/Dir");
}


- (void)testRelativeManifestIsResolvedAgainstCurrentDirectory;
{
    SyncTestOptions *options = [self parse:@[
        @"--workdir=/Work/Dir",
        @"--manifest=some/old.csv",
        @"/Some/Music"
    ]
                                     error:NULL];

    XCTAssertEqualObjects(
        options.manifestURL.path, @"/Current/Dir/some/old.csv"
    );
}


- (void)testManifestMayFollowMusicDir;
{
    SyncTestOptions *options =
        [self parse:@[@"/Some/Music", @"--manifest=/Some/old.csv"] error:NULL];

    XCTAssertEqualObjects(options.manifestURL.path, @"/Some/old.csv");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
}


- (void)testManifestWithoutValueFails;
{
    [self assertParsing:@[@"--manifest=", @"/Some/Music"]
         failsWithError:@"--manifest requires a MANIFEST_PATH value"];
    [self assertParsing:@[@"--manifest", @"/Some/Music"]
         failsWithError:@"--manifest requires a MANIFEST_PATH value"];
}


- (void)testShareNameDefaultsToNil;
{
    SyncTestOptions *options = [self parse:@[@"/Some/Music"] error:NULL];

    XCTAssertNil(options.shareName);
}


- (void)testShareNameIsUsedAsGiven;
{
    SyncTestOptions *options =
        [self parse:@[@"--share-name= My Mac ", @"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.shareName, @" My Mac ");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
}


- (void)testShareNameMayFollowMusicDir;
{
    SyncTestOptions *options =
        [self parse:@[@"/Some/Music", @"--share-name=My Mac"] error:NULL];

    XCTAssertEqualObjects(options.shareName, @"My Mac");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
}


- (void)testShareNameWithoutValueFails;
{
    [self assertParsing:@[@"--share-name=", @"/Some/Music"]
         failsWithError:@"--share-name requires a SHARE_NAME value"];
    [self assertParsing:@[@"--share-name", @"/Some/Music"]
         failsWithError:@"--share-name requires a SHARE_NAME value"];
}


- (void)testMissingMusicDirFails;
{
    [self assertParsing:@[] failsWithError:@"missing MUSIC_DIR"];
    [self assertParsing:@[@"--workdir=/Work/Dir"]
         failsWithError:@"missing MUSIC_DIR"];
}


- (void)testMissingProgramNameFails;
{
    NSError *error = nil;
    SyncTestOptions *options =
        [SyncTestOptions optionsWithArguments:@[]
                          currentDirectoryURL:_currentDirectoryURL
                                        error:&error];

    XCTAssertNil(options);
    XCTAssertEqualObjects(error.localizedDescription, @"missing MUSIC_DIR");
}


- (void)testWorkdirWithoutValueFails;
{
    [self assertParsing:@[@"--workdir=", @"/Some/Music"]
         failsWithError:@"--workdir requires a DIR value"];
    [self assertParsing:@[@"--workdir", @"/Some/Music"]
         failsWithError:@"--workdir requires a DIR value"];
}


- (void)testUnknownOptionFails;
{
    [self assertParsing:@[@"--verbose", @"/Some/Music"]
         failsWithError:@"unknown option --verbose"];
}


- (void)testExtraArgumentFails;
{
    [self assertParsing:@[@"/Some/Music", @"/Other/Music"]
         failsWithError:@"unexpected argument /Other/Music"];
}


@end


#endif
