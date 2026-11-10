#import "FileSystemDemo.h"


NSErrorDomain const FileSystemDemoErrorDomain = @"FileSystemDemoErrorDomain";


static NSString *_Nullable
string_value(NSDictionary *entry, NSString *key)
{
    id value = entry[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}


static NSDictionary *_Nullable
first_directory_entry(id json)
{
    if ( ! [json isKindOfClass:[NSArray class]]) return nil;
    for (id entry in json) {
        if (
            [entry isKindOfClass:[NSDictionary class]]
            && [string_value(entry, @"type") isEqualToString:@"directory"]
        ) {
            return entry;
        }
    }
    return nil;
}


static NSError *
no_directory_entry_error(void)
{
    return [NSError errorWithDomain:FileSystemDemoErrorDomain
                               code:FileSystemDemoErrorCodeNoDirectoryEntry
                           userInfo:nil];
}


// The demo data has only names, so the localized display name rule cannot
// apply. The hidden file rule is applied by leading dot and the package rule
// by flagging `.itlp` directories, the only packages in the data.
static void
index_directory(NSDictionary *entry,
                NSString *path,
                NSMutableDictionary<NSString *, FileSystemItemInfo *> *infoByPath,
                NSMutableDictionary<NSString *, NSArray<NSURL *> *> *contentsByPath)
{
    NSMutableArray<NSURL *> *contents = [NSMutableArray array];
    id children = entry[@"contents"];
    if ( ! [children isKindOfClass:[NSArray class]]) children = @[];
    for (id child in children) {
        if ( ! [child isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = string_value(child, @"name");
        if ( ! name || [name hasPrefix:@"."]) continue;
        NSString *type = string_value(child, @"type");
        NSString *childPath = [path stringByAppendingPathComponent:name];
        BOOL isDirectory = [type isEqualToString:@"directory"];
        BOOL isPackage = isDirectory && [name.pathExtension.lowercaseString isEqualToString:@"itlp"];
        infoByPath[childPath] = [[FileSystemItemInfo alloc] initWithIsDirectory:isDirectory
                                                                  isRegularFile:[type isEqualToString:@"file"]
                                                                      isPackage:isPackage
                                                                  localizedName:nil];
        [contents addObject:[NSURL fileURLWithPath:childPath isDirectory:isDirectory]];
        if (isDirectory) index_directory(child, childPath, infoByPath, contentsByPath);
    }
    contentsByPath[path] = [contents copy];
}


@implementation FileSystemDemo
{
    id<FileSystem> _fileSystem;
    NSError *_Nullable _error;
    NSDictionary<NSString *, FileSystemItemInfo *> *_infoByPath;
    NSDictionary<NSString *, NSArray<NSURL *> *> *_contentsByPath;
#if TARGET_OS_OSX
    NSMutableSet<NSData *> *_mintedBookmarks;
#endif
}


- (instancetype)initWithDemoData:(NSData *)demoData
                      fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if ( ! self) return nil;

    _fileSystem = fileSystem;
    _infoByPath = @{};
    _contentsByPath = @{};
#if TARGET_OS_OSX
    _mintedBookmarks = [NSMutableSet set];
#endif
    [self indexDemoData:demoData];

    return self;
}


- (void)indexDemoData:(NSData *)demoData;
{
    NSError *error;
    id json = [NSJSONSerialization JSONObjectWithData:demoData options:0 error:&error];
    if ( ! json) {
        _error = error;
        return;
    }
    NSDictionary *rootEntry = first_directory_entry(json);
    if ( ! rootEntry) {
        _error = no_directory_entry_error();
        return;
    }
    NSString *rootPath = string_value(rootEntry, @"name") ?: @"/";
    NSMutableDictionary<NSString *, FileSystemItemInfo *> *infoByPath = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSArray<NSURL *> *> *contentsByPath = [NSMutableDictionary dictionary];
    index_directory(rootEntry, rootPath, infoByPath, contentsByPath);
    _rootURL = [NSURL fileURLWithPath:rootPath isDirectory:YES];
    _infoByPath = [infoByPath copy];
    _contentsByPath = [contentsByPath copy];
}


- (nullable NSURL *)rootURLAndReturnError:(NSError **)error;
{
    if ( ! _rootURL && error) *error = _error;
    return _rootURL;
}


- (BOOL)isRootURL:(NSURL *)url;
{
    return [url.path isEqualToString:_rootURL.path];
}


- (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error;
{
    return [self rootURLAndReturnError:error];
}


// iOS locates its music root directory at `Music` inside Application Support,
// so the demo root's parent stands in for Application Support and the demo
// root directory must be named `Music`.
- (nullable NSURL *)getApplicationSupportDirectoryURLAndReturnError:(NSError **)error;
{
#if TARGET_OS_IOS
    return [self rootURLAndReturnError:error].URLByDeletingLastPathComponent;
#else
    return [_fileSystem getApplicationSupportDirectoryURLAndReturnError:error];
#endif
}


- (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error;
{
    return [self isRootURL:url] || [_fileSystem createDirectoryAt:url error:error];
}


- (BOOL)excludeFromBackup:(NSURL *)url error:(NSError **)error;
{
    return [self isRootURL:url] || [_fileSystem excludeFromBackup:url error:error];
}


- (nullable NSArray<NSURL *> *)listDirectory:(NSURL *)directory error:(NSError **)error;
{
    return _contentsByPath[directory.path] ?: [_fileSystem listDirectory:directory error:error];
}


- (nullable FileSystemItemInfo *)getFileInfo:(NSURL *)url error:(NSError **)error;
{
    return _infoByPath[url.path] ?: [_fileSystem getFileInfo:url error:error];
}


- (BOOL)removeItemAtURL:(NSURL *)URL
                  error:(NSError **)error;
{
    return [_fileSystem removeItemAtURL:URL error:error];
}


- (BOOL)cloneFile:(NSURL *)source
           toFile:(NSURL *)destination
            error:(NSError **)error;
{
    return [_fileSystem cloneFile:source toFile:destination error:error];
}


#if TARGET_OS_OSX
- (nullable NSData *)makeSecurityScopedBookmarkFor:(NSURL *)url error:(NSError **)error;
{
    NSData *bookmark = [_fileSystem makeSecurityScopedBookmarkFor:url error:error];
    if (bookmark) [self recordMintedBookmark:bookmark];
    return bookmark;
}


// A bookmark saved by an earlier launch resolves to the demo root, while one
// made in this session for a directory chosen in Settings resolves to that
// directory. Locating runs off the main thread and choosing runs on it, hence
// the lock around the minted bookmarks.
- (nullable ResolvedBookmark *)resolveSecurityScopedBookmark:(NSData *)bookmark error:(NSError **)error;
{
    if ([self wasMinted:bookmark]) {
        return [_fileSystem resolveSecurityScopedBookmark:bookmark error:error];
    }
    NSURL *rootURL = [self rootURLAndReturnError:error];
    if ( ! rootURL) return nil;
    return [[ResolvedBookmark alloc] initWithURL:rootURL isStale:NO];
}


- (void)recordMintedBookmark:(NSData *)bookmark;
{
    @synchronized (_mintedBookmarks) {
        [_mintedBookmarks addObject:bookmark];
    }
}


- (BOOL)wasMinted:(NSData *)bookmark;
{
    @synchronized (_mintedBookmarks) {
        return [_mintedBookmarks containsObject:bookmark];
    }
}


- (BOOL)startAccessing:(NSURL *)url;
{
    return [self isRootURL:url] || [_fileSystem startAccessing:url];
}


- (void)stopAccessing:(NSURL *)url;
{
    if ( ! [self isRootURL:url]) [_fileSystem stopAccessing:url];
}
#endif


@end
