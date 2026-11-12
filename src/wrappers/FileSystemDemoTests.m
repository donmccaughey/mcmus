#import <XCTest/XCTest.h>

#import "FileSystemDemo.h"
#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"

@interface FileSystemDemoTests : XCTestCase
@end

@implementation FileSystemDemoTests {
    FileSystemFake *_fileSystem;
}

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    _fileSystem = [FileSystemFake new];
}

// The fixtures use single quotes so they read without escapes.
- (FileSystemDemo *)demo:(NSString *)json
{
    NSString *quoted = [json stringByReplacingOccurrencesOfString:@"'"
                                                       withString:@"\""];
    return [[FileSystemDemo alloc]
        initWithDemoData:[quoted dataUsingEncoding:NSUTF8StringEncoding]
              fileSystem:_fileSystem];
}

- (FileSystemDemo *)demoWithTrackInRoot
{
    return
        [self demo:@"[{'type':'directory','name':'/Users/demo/"
                   @"Music','contents':[{'type':'file','name':'Song.mp3'}]}]"];
}

- (NSURL *)directory:(NSString *)path
{
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

- (NSURL *)file:(NSString *)path
{
    return [NSURL fileURLWithPath:path isDirectory:NO];
}

- (NSArray<NSString *> *)pathsIn:(NSString *)path
                        listedBy:(FileSystemDemo *)demo
{
    NSError *error;
    NSArray<NSURL *> *urls = [demo listDirectory:[self directory:path]
                                           error:&error];
    XCTAssertNotNil(urls, @"%@", error);
    return [urls valueForKey:@"path"];
}

- (FileSystemItemInfo *)infoFor:(NSString *)path from:(FileSystemDemo *)demo
{
    NSError *error;
    FileSystemItemInfo *info = [demo getFileInfo:[self file:path] error:&error];
    XCTAssertNotNil(info, @"%@", error);
    return info;
}

- (void)testDemoFilesHaveZeroSize
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    unsigned long long size = 42;
    NSError *error;
    BOOL ok = [demo getSize:&size
                     ofFile:[self file:@"/Users/demo/Music/Song.mp3"]
                      error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqual(size, 0ULL);
}

- (void)testSizeOfFileOutsideDemoRootComesFromWrappedFileSystem
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];
    [_fileSystem addPath:@"/Users/real/Music/Song.mp3" size:4096];

    unsigned long long size = 0;
    NSError *error;
    BOOL ok = [demo getSize:&size
                     ofFile:[self file:@"/Users/real/Music/Song.mp3"]
                      error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqual(size, 4096ULL);
}

- (void)testDemoFilesHaveNoContents
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    __block NSUInteger chunks = 0;
    NSError *error;
    BOOL ok =
        [demo readFile:[self file:@"/Users/demo/Music/Song.mp3"]
                chunks:^(const void *bytes, size_t length) { chunks += 1; }
                 error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqual(chunks, 0UL);
}

- (void)testContentsOfFileOutsideDemoRootComeFromWrappedFileSystem
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];
    NSData *contents = [@"0123456789" dataUsingEncoding:NSUTF8StringEncoding];
    [_fileSystem addPath:@"/Users/real/Music/Song.mp3" contents:contents];

    NSMutableData *read = [NSMutableData data];
    NSError *error;
    BOOL ok = [demo readFile:[self file:@"/Users/real/Music/Song.mp3"]
                      chunks:^(const void *bytes, size_t length) {
                          [read appendBytes:bytes length:length];
                      }
                       error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqualObjects(read, contents);
}

- (void)testRootDirectoryNameBecomesRootURL
{
    FileSystemDemo *demo = [self demo:
            @"[{'type':'directory','name':'/Users/demo/Music','contents':[]}]"];

    XCTAssertEqualObjects(demo.rootURL.path, @"/Users/demo/Music");
    XCTAssertTrue(demo.rootURL.hasDirectoryPath);
    NSError *error;
    XCTAssertEqualObjects([demo getMusicDirectoryURLAndReturnError:&error].path,
        @"/Users/demo/Music");
    XCTAssertNil(error);
    XCTAssertEqualObjects(
        [self pathsIn:@"/Users/demo/Music" listedBy:demo], @[]);
}

- (void)testRootDirectoryWithoutNameUsesSlash
{
    FileSystemDemo *demo = [self demo:@"[{'type':'directory','contents':[{'"
                                      @"type':'file','name':'Song.mp3'}]}]"];

    XCTAssertEqualObjects(demo.rootURL.path, @"/");
    XCTAssertEqualObjects([self pathsIn:@"/" listedBy:demo], @[@"/Song.mp3"]);
}

- (void)testRootDirectoryWithoutContentsListsNothing
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music'}]"];

    XCTAssertEqualObjects([self pathsIn:@"/Music" listedBy:demo], @[]);
}

- (void)testFirstDirectoryEntryIsUsedAsRoot
{
    _fileSystem.unlistableDirectories = [NSSet setWithObject:@"/Other"];
    FileSystemDemo *demo =
        [self demo:@"["
                    "    {'type':'report','directories':1,'files':1},"
                    "    "
                    "{'type':'directory','name':'/"
                    "Music','contents':[{'type':'file','name':'Song.mp3'}]},"
                    "    "
                    "{'type':'directory','name':'/"
                    "Other','contents':[{'type':'file','name':'Other.mp3'}]}"
                    "]"];

    XCTAssertEqualObjects(demo.rootURL.path, @"/Music");
    XCTAssertEqualObjects(
        [self pathsIn:@"/Music" listedBy:demo], @[@"/Music/Song.mp3"]);
    NSError *error;
    XCTAssertNil([demo listDirectory:[self directory:@"/Other"] error:&error]);
    XCTAssertEqualObjects(fileSystemFakeErrorPath(error), @"/Other");
}

- (void)testChildrenAreListedInDataOrder
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music','contents':["
                    "    {'type':'file','name':'Track 10.mp3'},"
                    "    {'type':'file','name':'track 2.mp3'},"
                    "    {'type':'directory','name':'B folder','contents':[]},"
                    "    {'type':'directory','name':'a folder','contents':[]}"
                    "]}]"];

    NSArray<NSURL *> *urls = [demo listDirectory:[self directory:@"/Music"]
                                           error:NULL];
    XCTAssertEqualObjects([urls valueForKey:@"path"], (@[
        @"/Music/Track 10.mp3",
        @"/Music/track 2.mp3",
        @"/Music/B folder",
        @"/Music/a folder",
    ]));
    XCTAssertFalse(urls[0].hasDirectoryPath);
    XCTAssertTrue(urls[2].hasDirectoryPath);
}

- (void)testNestedDirectoriesAreIndexed
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music','contents':["
                    "    {'type':'directory','name':'Artist','contents':["
                    "        {'type':'directory','name':'Album','contents':["
                    "            {'type':'file','name':'01 Song.mp3'}"
                    "        ]}"
                    "    ]}"
                    "]}]"];

    XCTAssertEqualObjects(
        [self pathsIn:@"/Music" listedBy:demo], @[@"/Music/Artist"]);
    XCTAssertEqualObjects([self pathsIn:@"/Music/Artist" listedBy:demo],
        @[@"/Music/Artist/Album"]);
    XCTAssertEqualObjects([self pathsIn:@"/Music/Artist/Album" listedBy:demo],
        @[@"/Music/Artist/Album/01 Song.mp3"]);
    XCTAssertTrue([self infoFor:@"/Music/Artist/Album/01 Song.mp3" from:demo]
            .isRegularFile);
}

- (void)testFileInfoClassifiesEntries
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music','contents':["
                    "    {'type':'directory','name':'Album','contents':[]},"
                    "    {'type':'file','name':'Song.mp3'},"
                    "    {'type':'link','name':'Link.mp3'}"
                    "]}]"];

    FileSystemItemInfo *album = [self infoFor:@"/Music/Album" from:demo];
    XCTAssertTrue(album.isDirectory);
    XCTAssertFalse(album.isRegularFile);
    XCTAssertFalse(album.isPackage);
    XCTAssertNil(album.localizedName);

    FileSystemItemInfo *song = [self infoFor:@"/Music/Song.mp3" from:demo];
    XCTAssertFalse(song.isDirectory);
    XCTAssertTrue(song.isRegularFile);
    XCTAssertFalse(song.isPackage);
    XCTAssertNil(song.localizedName);

    FileSystemItemInfo *link = [self infoFor:@"/Music/Link.mp3" from:demo];
    XCTAssertFalse(link.isDirectory);
    XCTAssertFalse(link.isRegularFile);
    XCTAssertFalse(link.isPackage);
}

- (void)testITunesLPDirectoriesArePackages
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music','contents':["
                    "    {'type':'directory','name':'Album.itlp','contents':["
                    "        {'type':'file','name':'Inside.mp3'}"
                    "    ]},"
                    "    {'type':'directory','name':'Loud.ITLP','contents':[]},"
                    "    {'type':'file','name':'Song.mp3'}"
                    "]}]"];

    FileSystemItemInfo *album = [self infoFor:@"/Music/Album.itlp" from:demo];
    XCTAssertTrue(album.isDirectory);
    XCTAssertTrue(album.isPackage);
    FileSystemItemInfo *loud = [self infoFor:@"/Music/Loud.ITLP" from:demo];
    XCTAssertTrue(loud.isDirectory);
    XCTAssertTrue(loud.isPackage);
    XCTAssertFalse([self infoFor:@"/Music/Song.mp3" from:demo].isPackage);
    XCTAssertEqualObjects([self pathsIn:@"/Music/Album.itlp" listedBy:demo],
        @[@"/Music/Album.itlp/Inside.mp3"]);
}

- (void)testHiddenFilesAndDirectoriesAreOmitted
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music','contents':["
                    "    {'type':'file','name':'.DS_Store'},"
                    "    {'type':'file','name':'._Song.mp3'},"
                    "    {'type':'directory','name':'.hidden','contents':["
                    "        {'type':'file','name':'Secret.mp3'}"
                    "    ]},"
                    "    {'type':'file','name':'Song.mp3'}"
                    "]}]"];

    XCTAssertEqualObjects(
        [self pathsIn:@"/Music" listedBy:demo], @[@"/Music/Song.mp3"]);
    NSError *error;
    XCTAssertNil([demo getFileInfo:[self directory:@"/Music/.hidden"]
                             error:&error]);
    XCTAssertEqualObjects(fileSystemFakeErrorPath(error), @"/Music/.hidden");
}

- (void)testEntriesWithoutNamesAreOmitted
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'directory','name':'/Music','contents':["
                    "    {'type':'file'},"
                    "    "
                    "{'type':'directory','contents':[{'type':'file','name':'"
                    "Song.mp3'}]},"
                    "    {'type':'file','name':'Song.mp3'}"
                    "]}]"];

    XCTAssertEqualObjects(
        [self pathsIn:@"/Music" listedBy:demo], @[@"/Music/Song.mp3"]);
}

- (void)testInvalidJSONIsReportedWhenLocatingTheMusicDirectory
{
    FileSystemDemo *demo = [self demo:@"not json"];

    XCTAssertNil(demo.rootURL);
    NSError *error;
    XCTAssertNil([demo getMusicDirectoryURLAndReturnError:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSPropertyListReadCorruptError);
}

- (void)testEmptyDataIsReportedWhenLocatingTheMusicDirectory
{
    FileSystemDemo *demo =
        [[FileSystemDemo alloc] initWithDemoData:[NSData data]
                                      fileSystem:_fileSystem];

    XCTAssertNil(demo.rootURL);
    NSError *error;
    XCTAssertNil([demo getMusicDirectoryURLAndReturnError:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
}

- (void)testMissingDirectoryEntryIsReportedWhenLocatingTheMusicDirectory
{
    FileSystemDemo *demo =
        [self demo:@"[{'type':'report','directories':0,'files':0}]"];

    XCTAssertNil(demo.rootURL);
    NSError *error;
    XCTAssertNil([demo getMusicDirectoryURLAndReturnError:&error]);
    XCTAssertEqualObjects(error.domain, FileSystemDemoErrorDomain);
    XCTAssertEqual(error.code, FileSystemDemoErrorCodeNoDirectoryEntry);
}

- (void)testPathsOutsideTheDemoTreeAreForwarded
{
    [_fileSystem addPath:@"/Other/Song.mp3"];
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    XCTAssertEqualObjects(
        [self pathsIn:@"/Other" listedBy:demo], @[@"/Other/Song.mp3"]);
    XCTAssertTrue([self infoFor:@"/Other/Song.mp3" from:demo].isRegularFile);
}

- (void)testFileOperationsAreForwarded
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    XCTAssertTrue([demo cloneFile:[self directory:@"/Users/demo/Music"]
                           toFile:[self directory:@"/Snapshot"]
                            error:NULL]);
    XCTAssertEqualObjects(_fileSystem.clonedSources, @[@"/Users/demo/Music"]);
    XCTAssertEqualObjects(_fileSystem.clonedDestinations, @[@"/Snapshot"]);
    _fileSystem.removeItemAtURLError = [NSError errorWithDomain:@"Remove" code:1
                                                       userInfo:nil];
    NSError *error;
    XCTAssertFalse([demo removeItemAtURL:[self directory:@"/Snapshot"]
                                   error:&error]);
    XCTAssertEqualObjects(error.domain, @"Remove");
}

- (void)testDemoRootIsCreatedAndExcludedFromBackupWithoutTheRealFileSystem
{
    _fileSystem.uncreatableDirectories = [NSSet setWithObject:@"/Other"];
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    XCTAssertTrue([demo createDirectoryAt:[self directory:@"/Users/demo/Music"]
                                    error:NULL]);
    XCTAssertTrue([demo excludeFromBackup:[self directory:@"/Users/demo/Music"]
                                    error:NULL]);
    NSError *error;
    XCTAssertFalse([demo createDirectoryAt:[self directory:@"/Other"]
                                     error:&error]);
    XCTAssertEqualObjects(fileSystemFakeErrorPath(error), @"/Other");
    XCTAssertFalse([demo excludeFromBackup:[self directory:@"/Other"]
                                     error:&error]);
    XCTAssertEqualObjects(fileSystemFakeErrorPath(error), @"/Other");
}

#if TARGET_OS_OSX
- (void)testApplicationSupportDirectoryIsForwarded
{
    _fileSystem.applicationSupportDirectoryURL =
        [self directory:@"/AppSupport"];
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    XCTAssertEqualObjects(
        [demo getApplicationSupportDirectoryURLAndReturnError:NULL].path,
        @"/AppSupport");
}

- (void)testSavedBookmarkResolvesToDemoRoot
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    NSError *error;
    ResolvedBookmark *resolved =
        [demo resolveSecurityScopedBookmark:[FileSystemFake
                                                bookmarkForPath:@"/Saved/Music"]
                                      error:&error];
    XCTAssertEqualObjects(resolved.url.path, @"/Users/demo/Music");
    XCTAssertFalse(resolved.isStale);
    XCTAssertNil(error);
}

- (void)testBookmarkMadeHereResolvesToItsOwnDirectory
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    NSData *bookmark =
        [demo makeSecurityScopedBookmarkFor:[self directory:@"/Chosen"]
                                      error:NULL];
    XCTAssertEqualObjects(_fileSystem.bookmarked, @[@"/Chosen"]);
    ResolvedBookmark *resolved = [demo resolveSecurityScopedBookmark:bookmark
                                                               error:NULL];
    XCTAssertEqualObjects(resolved.url.path, @"/Chosen");
}

- (void)testInvalidDataFailsBookmarkResolution
{
    FileSystemDemo *demo = [self demo:@"not json"];

    NSError *error;
    XCTAssertNil(
        [demo resolveSecurityScopedBookmark:[FileSystemFake
                                                bookmarkForPath:@"/Saved/Music"]
                                      error:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
}

- (void)testAccessingDemoRootNeedsNoRealAccess
{
    _fileSystem.inaccessiblePaths = [NSSet setWithObject:@"/Denied"];
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    XCTAssertTrue([demo startAccessing:[self directory:@"/Users/demo/Music"]]);
    [demo stopAccessing:[self directory:@"/Users/demo/Music"]];
    XCTAssertEqualObjects(_fileSystem.started, @[]);
    XCTAssertEqualObjects(_fileSystem.stopped, @[]);

    XCTAssertTrue([demo startAccessing:[self directory:@"/Other"]]);
    XCTAssertFalse([demo startAccessing:[self directory:@"/Denied"]]);
    [demo stopAccessing:[self directory:@"/Other"]];
    XCTAssertEqualObjects(_fileSystem.started, @[@"/Other"]);
    XCTAssertEqualObjects(_fileSystem.stopped, @[@"/Other"]);
}
#else
- (void)testApplicationSupportDirectoryIsParentOfDemoRoot
{
    FileSystemDemo *demo = [self demoWithTrackInRoot];

    NSError *error;
    XCTAssertEqualObjects(
        [demo getApplicationSupportDirectoryURLAndReturnError:&error].path,
        @"/Users/demo");
    XCTAssertNil(error);
}

- (void)testInvalidDataFailsApplicationSupportDirectoryLookup
{
    FileSystemDemo *demo = [self demo:@"not json"];

    NSError *error;
    XCTAssertNil([demo getApplicationSupportDirectoryURLAndReturnError:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
}
#endif

@end
