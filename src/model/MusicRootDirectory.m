#import "MusicRootDirectory.h"

#if TARGET_OS_OSX
static MusicRootDirectory *_Nullable accessBookmark(NSData *bookmark,
                                                    id<FileSystem> fileSystem,
                                                    id<Preferences> preferences) {
    ResolvedBookmark *resolved = [fileSystem resolveSecurityScopedBookmark:bookmark error:NULL];
    if (!resolved) {
        return nil;
    }
    if (resolved.isStale) {
        NSData *fresh = [fileSystem makeSecurityScopedBookmarkFor:resolved.url error:NULL];
        if (fresh) {
            [preferences setMusicRootDirectoryBookmark:fresh];
        }
    }
    if (![fileSystem startAccessing:resolved.url]) {
        return nil;
    }
    return [[MusicRootDirectory alloc] initWithURL:resolved.url isSecurityScoped:YES];
}
#endif

@implementation MusicRootDirectory

- (instancetype)initWithURL:(NSURL *)url isSecurityScoped:(BOOL)isSecurityScoped {
    self = [super init];
    if (self) {
        _url = [url copy];
        _isSecurityScoped = isSecurityScoped;
    }
    return self;
}

+ (nullable MusicRootDirectory *)locateWithFileSystem:(id<FileSystem>)fileSystem
                                          preferences:(id<Preferences>)preferences
                                                error:(NSError **)error {
#if TARGET_OS_OSX
    NSData *bookmark = [preferences getMusicRootDirectoryBookmark];
    if (bookmark) {
        MusicRootDirectory *saved = accessBookmark(bookmark, fileSystem, preferences);
        if (saved) {
            return saved;
        }
    }
    // The Music folder entitlement grants access without a bookmark.
    NSURL *url = [fileSystem getMusicDirectoryURLAndReturnError:error];
    if (!url) {
        return nil;
    }
    return [[MusicRootDirectory alloc] initWithURL:url isSecurityScoped:NO];
#else
    NSURL *applicationSupport = [fileSystem getApplicationSupportDirectoryURLAndReturnError:error];
    if (!applicationSupport) {
        return nil;
    }
    NSURL *url = [applicationSupport URLByAppendingPathComponent:@"Music" isDirectory:YES];
    if (![fileSystem createDirectoryAt:url error:error]) {
        return nil;
    }
    if (![fileSystem excludeFromBackup:url error:error]) {
        return nil;
    }
    return [[MusicRootDirectory alloc] initWithURL:url isSecurityScoped:NO];
#endif
}

#if TARGET_OS_OSX
+ (MusicRootDirectory *)choose:(NSURL *)url
                    fileSystem:(id<FileSystem>)fileSystem
                   preferences:(id<Preferences>)preferences {
    // The open panel already grants access for this session, so a
    // bookmark failure only loses the choice at the next launch.
    NSData *bookmark = [fileSystem makeSecurityScopedBookmarkFor:url error:NULL];
    if (!bookmark) {
        return [[MusicRootDirectory alloc] initWithURL:url isSecurityScoped:NO];
    }
    [preferences setMusicRootDirectoryBookmark:bookmark];
    return accessBookmark(bookmark, fileSystem, preferences)
        ?: [[MusicRootDirectory alloc] initWithURL:url isSecurityScoped:NO];
}

- (void)stopAccessingWithFileSystem:(id<FileSystem>)fileSystem {
    if (_isSecurityScoped) {
        [fileSystem stopAccessing:_url];
    }
}
#endif

@end
