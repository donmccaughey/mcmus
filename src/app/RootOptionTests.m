#import <XCTest/XCTest.h>

#import "RootOption.h"

#if TARGET_OS_OSX
@interface RootOptionTests : XCTestCase
@end

@implementation RootOptionTests

- (void)testReturnsDirectoryURLForPathAfterOption
{
    NSURL *url = rootOptionURL(@[@"MC Mus", @"--root", @"/Some/Music"]);

    XCTAssertEqualObjects(url.path, @"/Some/Music");
    XCTAssertTrue(url.hasDirectoryPath);
}

- (void)testReturnsNilWhenOptionIsAbsent
{
    XCTAssertNil(rootOptionURL(@[@"MC Mus", @"/Some/Music"]));
}

- (void)testReturnsNilWhenOptionHasNoPath
{
    XCTAssertNil(rootOptionURL(@[@"MC Mus", @"--root"]));
}

- (void)testReturnsNilInDemoMode
{
    XCTAssertNil(
        rootOptionURL(@[@"MC Mus", @"--demo", @"--root", @"/Some/Music"]));
    XCTAssertNil(
        rootOptionURL(@[@"MC Mus", @"--root", @"/Some/Music", @"--demo"]));
}

- (void)testResolvesRelativePathAgainstWorkingDirectory
{
    NSURL *url = rootOptionURL(@[@"MC Mus", @"--root", @"some/music"]);

    NSString *workingDirectory =
        NSFileManager.defaultManager.currentDirectoryPath;
    XCTAssertEqualObjects(url.path,
        [workingDirectory stringByAppendingPathComponent:@"some/music"]);
}

@end
#endif
