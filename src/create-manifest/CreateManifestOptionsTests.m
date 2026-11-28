#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "CreateManifestOptions.h"


@interface CreateManifestOptionsTests : XCTestCase
@end


@implementation CreateManifestOptionsTests {
    NSURL *_currentDirectoryURL;
}


- (void)setUp;
{
    [super setUp];
    _currentDirectoryURL = [NSURL fileURLWithPath:@"/Current/Dir"
                                      isDirectory:YES];
}


- (nullable CreateManifestOptions *)parse:(NSArray<NSString *> *)arguments
                                    error:(NSError **)error;
{
    NSArray<NSString *> *withProgramName =
        [@[@"create-manifest"] arrayByAddingObjectsFromArray:arguments];
    return [CreateManifestOptions optionsWithArguments:withProgramName
                                   currentDirectoryURL:_currentDirectoryURL
                                                 error:error];
}


- (void)assertParsing:(NSArray<NSString *> *)arguments
       failsWithError:(NSString *)description;
{
    NSError *error = nil;
    CreateManifestOptions *options = [self parse:arguments error:&error];

    XCTAssertNil(options);
    XCTAssertEqualObjects(error.localizedDescription, description);
}


- (void)testAbsoluteMusicDirIsUsedAsGiven;
{
    CreateManifestOptions *options = [self parse:@[@"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
    XCTAssertTrue(options.musicDirectoryURL.hasDirectoryPath);
}


- (void)testRelativeMusicDirIsResolvedAgainstCurrentDirectory;
{
    CreateManifestOptions *options = [self parse:@[@"some/music"] error:NULL];

    XCTAssertEqualObjects(
        options.musicDirectoryURL.path, @"/Current/Dir/some/music"
    );
}


- (void)testWorkingDirectoryDefaultsToCurrentDirectory;
{
    CreateManifestOptions *options = [self parse:@[@"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Current/Dir");
}


- (void)testAbsoluteWorkdirIsUsedAsGiven;
{
    CreateManifestOptions *options =
        [self parse:@[@"--workdir=/Work/Dir", @"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Work/Dir");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
}


- (void)testRelativeWorkdirIsResolvedAgainstCurrentDirectory;
{
    CreateManifestOptions *options =
        [self parse:@[@"--workdir=work/dir", @"/Some/Music"] error:NULL];

    XCTAssertEqualObjects(
        options.workingDirectoryURL.path, @"/Current/Dir/work/dir"
    );
}


- (void)testWorkdirMayFollowMusicDir;
{
    CreateManifestOptions *options =
        [self parse:@[@"/Some/Music", @"--workdir=/Work/Dir"] error:NULL];

    XCTAssertEqualObjects(options.workingDirectoryURL.path, @"/Work/Dir");
    XCTAssertEqualObjects(options.musicDirectoryURL.path, @"/Some/Music");
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
    CreateManifestOptions *options =
        [CreateManifestOptions optionsWithArguments:@[]
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
