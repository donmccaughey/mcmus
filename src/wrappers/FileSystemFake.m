#import "FileSystemFake.h"

NSErrorDomain const FileSystemFakeErrorDomain = @"FileSystemFakeErrorDomain";

static NSError *operationFailed(NSString *path) {
    return [NSError errorWithDomain:FileSystemFakeErrorDomain
                               code:FileSystemFakeErrorCodeOperationFailed
                           userInfo:@{NSFilePathErrorKey: path}];
}

static void fail(NSString *path, NSError **error) {
    if (error) {
        *error = operationFailed(path);
    }
}

@implementation FileSystemFakeEntry

- (instancetype)initWithPath:(NSString *)path
                        kind:(FileSystemFakeKind)kind
               localizedName:(nullable NSString *)localizedName
                        size:(unsigned long long)size
                    contents:(nullable NSData *)contents;
{
    self = [super init];
    if ( ! self) return nil;

    _path = [path copy];
    _kind = kind;
    _localizedName = [localizedName copy];
    _size = size;
    _contents = [contents copy];

    return self;
}

- (instancetype)initWithPath:(NSString *)path
                        kind:(FileSystemFakeKind)kind
               localizedName:(nullable NSString *)localizedName
                        size:(unsigned long long)size;
{
    return [self initWithPath:path kind:kind localizedName:localizedName size:size contents:nil];
}

- (instancetype)initWithPath:(NSString *)path
                        kind:(FileSystemFakeKind)kind
               localizedName:(nullable NSString *)localizedName;
{
    return [self initWithPath:path kind:kind localizedName:localizedName size:0];
}

@end

@implementation FileSystemFake {
    NSMutableArray<FileSystemFakeEntry *> *_entries;
    NSMutableArray<NSString *> *_bookmarked;
    NSMutableArray<NSString *> *_started;
    NSMutableArray<NSString *> *_stopped;
    NSMutableArray<NSString *> *_clonedSources;
    NSMutableArray<NSString *> *_clonedDestinations;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
        _unlistableDirectories = [NSSet set];
        _unreadableEntries = [NSSet set];
        _unsizeableFiles = [NSSet set];
        _unreadableFiles = [NSSet set];
        _uncreatableDirectories = [NSSet set];
        _unbookmarkablePaths = [NSSet set];
        _unresolvableBookmarks = [NSSet set];
        _staleBookmarks = [NSSet set];
        _inaccessiblePaths = [NSSet set];
        _bookmarked = [NSMutableArray array];
        _started = [NSMutableArray array];
        _stopped = [NSMutableArray array];
        _clonedSources = [NSMutableArray array];
        _clonedDestinations = [NSMutableArray array];
    }
    return self;
}

- (NSArray<FileSystemFakeEntry *> *)entries {
    return [_entries copy];
}

- (void)setEntries:(NSArray<FileSystemFakeEntry *> *)entries {
    _entries = [entries mutableCopy];
}

- (NSArray<NSString *> *)bookmarked {
    return [_bookmarked copy];
}

- (NSArray<NSString *> *)started {
    return [_started copy];
}

- (NSArray<NSString *> *)stopped {
    return [_stopped copy];
}

- (NSArray<NSString *> *)clonedSources {
    return [_clonedSources copy];
}

- (NSArray<NSString *> *)clonedDestinations {
    return [_clonedDestinations copy];
}

- (void)addPath:(NSString *)path {
    [self addPath:path kind:FileSystemFakeKindFile localizedName:nil];
}

- (void)addPath:(NSString *)path kind:(FileSystemFakeKind)kind {
    [self addPath:path kind:kind localizedName:nil];
}

- (void)addPath:(NSString *)path kind:(FileSystemFakeKind)kind localizedName:(nullable NSString *)localizedName {
    [_entries addObject:[[FileSystemFakeEntry alloc] initWithPath:path kind:kind localizedName:localizedName]];
}

- (void)addPath:(NSString *)path size:(unsigned long long)size;
{
    [_entries addObject:[[FileSystemFakeEntry alloc] initWithPath:path
                                                             kind:FileSystemFakeKindFile
                                                    localizedName:nil
                                                             size:size]];
}

- (void)addPath:(NSString *)path contents:(NSData *)contents;
{
    [_entries addObject:[[FileSystemFakeEntry alloc] initWithPath:path
                                                             kind:FileSystemFakeKindFile
                                                    localizedName:nil
                                                             size:contents.length
                                                         contents:contents]];
}

+ (NSData *)bookmarkForPath:(NSString *)path {
    return [path dataUsingEncoding:NSUTF8StringEncoding];
}

- (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error {
    if (!_musicDirectoryURL) {
        fail(@"getMusicDirectoryURL", error);
    }
    return _musicDirectoryURL;
}

- (nullable NSURL *)getApplicationSupportDirectoryURLAndReturnError:(NSError **)error {
    if (!_applicationSupportDirectoryURL) {
        fail(@"getApplicationSupportDirectoryURL", error);
    }
    return _applicationSupportDirectoryURL;
}

- (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error {
    if ([_uncreatableDirectories containsObject:url.path]) {
        fail(url.path, error);
        return NO;
    }
    return YES;
}

- (BOOL)excludeFromBackup:(NSURL *)url error:(NSError **)error {
    fail(url.path, error);
    return NO;
}

// Entries come back in insertion order so tests can see the loader sort.
- (nullable NSArray<NSURL *> *)listDirectory:(NSURL *)directory error:(NSError **)error {
    if ([_unlistableDirectories containsObject:directory.path]) {
        fail(directory.path, error);
        return nil;
    }
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (FileSystemFakeEntry *entry in _entries) {
        if (![entry.path.stringByDeletingLastPathComponent isEqualToString:directory.path]) {
            continue;
        }
        BOOL isDirectory = entry.kind == FileSystemFakeKindDirectory || entry.kind == FileSystemFakeKindPackage;
        [urls addObject:[NSURL fileURLWithPath:entry.path isDirectory:isDirectory]];
    }
    return urls;
}

- (nullable FileSystemItemInfo *)getFileInfo:(NSURL *)url error:(NSError **)error {
    FileSystemFakeEntry *entry = [self entryForPath:url.path];
    if ([_unreadableEntries containsObject:url.path] || !entry) {
        fail(url.path, error);
        return nil;
    }
    return [[FileSystemItemInfo alloc]
        initWithIsDirectory:entry.kind == FileSystemFakeKindDirectory || entry.kind == FileSystemFakeKindPackage
              isRegularFile:entry.kind == FileSystemFakeKindFile
                  isPackage:entry.kind == FileSystemFakeKindPackage
              localizedName:entry.localizedName];
}

- (BOOL)getSize:(unsigned long long *)size
         ofFile:(NSURL *)url
          error:(NSError **)error;
{
    FileSystemFakeEntry *entry = [self entryForPath:url.path];
    if ([_unsizeableFiles containsObject:url.path] || ! entry) {
        fail(url.path, error);
        return NO;
    }
    *size = entry.size;
    return YES;
}

// Contents arrive a few bytes at a time so tests see callers handle a file
// that spans several chunks.
- (BOOL)readFile:(NSURL *)url
          chunks:(void (NS_NOESCAPE ^)(const void *bytes, size_t length))chunk
           error:(NSError **)error;
{
    static const NSUInteger chunkLength = 4;
    FileSystemFakeEntry *entry = [self entryForPath:url.path];
    if ([_unreadableFiles containsObject:url.path] || ! entry) {
        fail(url.path, error);
        return NO;
    }
    NSData *contents = entry.contents ?: [NSData data];
    const uint8_t *bytes = contents.bytes;
    for (NSUInteger offset = 0; offset < contents.length; offset += chunkLength) {
        chunk(bytes + offset, MIN(chunkLength, contents.length - offset));
    }
    return YES;
}

- (nullable FileSystemFakeEntry *)entryForPath:(NSString *)path {
    for (FileSystemFakeEntry *entry in _entries) {
        if ([entry.path isEqualToString:path]) {
            return entry;
        }
    }
    return nil;
}

- (BOOL)removeItemAtURL:(NSURL *)URL
                  error:(NSError **)error;
{
    if (_removeItemAtURLError) {
        if (error) *error = _removeItemAtURLError;
        return NO;
    }
    return YES;
}

- (BOOL)cloneFile:(NSURL *)source
           toFile:(NSURL *)destination
            error:(NSError **)error;
{
    if (_cloneFileToFileError) {
        if (error) *error = _cloneFileToFileError;
        return NO;
    }
    [_clonedSources addObject:source.path];
    [_clonedDestinations addObject:destination.path];
    return YES;
}

#if TARGET_OS_OSX
- (nullable NSData *)makeSecurityScopedBookmarkFor:(NSURL *)url error:(NSError **)error {
    if ([_unbookmarkablePaths containsObject:url.path]) {
        fail(url.path, error);
        return nil;
    }
    [_bookmarked addObject:url.path];
    return [FileSystemFake bookmarkForPath:url.path];
}

- (nullable ResolvedBookmark *)resolveSecurityScopedBookmark:(NSData *)bookmark error:(NSError **)error {
    NSString *path = [[NSString alloc] initWithData:bookmark encoding:NSUTF8StringEncoding] ?: @"";
    if ([_unresolvableBookmarks containsObject:path]) {
        fail(path, error);
        return nil;
    }
    return [[ResolvedBookmark alloc] initWithURL:[NSURL fileURLWithPath:path isDirectory:YES]
                                         isStale:[_staleBookmarks containsObject:path]];
}

- (BOOL)startAccessing:(NSURL *)url {
    if ([_inaccessiblePaths containsObject:url.path]) {
        return NO;
    }
    [_started addObject:url.path];
    return YES;
}

- (void)stopAccessing:(NSURL *)url {
    [_stopped addObject:url.path];
}
#endif

@end
