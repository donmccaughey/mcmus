#import "FileSystemReal.h"

// Prefetched by listDirectory so getFileInfo reads from the URL's cache
// instead of going back to disk for each entry.
static NSArray<NSURLResourceKey> *fileInfoKeys(void) {
    return @[
        NSURLIsDirectoryKey, NSURLIsRegularFileKey, NSURLIsPackageKey, NSURLLocalizedNameKey
    ];
}

@implementation FileSystemReal

- (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error {
    NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSMusicDirectory
                                                        inDomain:NSUserDomainMask
                                               appropriateForURL:nil
                                                          create:YES
                                                           error:error];
    // Inside the App Sandbox the home directory is the app container, whose
    // Music entry is a symlink to the real ~/Music; resolve it so the user
    // sees the real path.
    return url.URLByResolvingSymlinksInPath;
}

- (nullable NSURL *)getApplicationSupportDirectoryURLAndReturnError:(NSError **)error {
    return [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                  inDomain:NSUserDomainMask
                                         appropriateForURL:nil
                                                    create:YES
                                                     error:error];
}

- (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtURL:url
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:error];
}

- (BOOL)excludeFromBackup:(NSURL *)url error:(NSError **)error {
    return [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:error];
}

- (nullable NSArray<NSURL *> *)listDirectory:(NSURL *)directory error:(NSError **)error {
    return [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory
                                         includingPropertiesForKeys:fileInfoKeys()
                                                            options:NSDirectoryEnumerationSkipsHiddenFiles
                                                              error:error];
}

- (nullable FileSystemItemInfo *)getFileInfo:(NSURL *)url error:(NSError **)error {
    NSDictionary<NSURLResourceKey, id> *values = [url resourceValuesForKeys:fileInfoKeys() error:error];
    if (!values) {
        return nil;
    }
    return [[FileSystemItemInfo alloc] initWithIsDirectory:[values[NSURLIsDirectoryKey] boolValue]
                                             isRegularFile:[values[NSURLIsRegularFileKey] boolValue]
                                                 isPackage:[values[NSURLIsPackageKey] boolValue]
                                             localizedName:values[NSURLLocalizedNameKey]];
}

#if TARGET_OS_OSX
- (nullable NSData *)makeSecurityScopedBookmarkFor:(NSURL *)url error:(NSError **)error {
    return [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
         includingResourceValuesForKeys:nil
                          relativeToURL:nil
                                  error:error];
}

- (nullable ResolvedBookmark *)resolveSecurityScopedBookmark:(NSData *)bookmark error:(NSError **)error {
    BOOL isStale = NO;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                           options:NSURLBookmarkResolutionWithSecurityScope
                                     relativeToURL:nil
                               bookmarkDataIsStale:&isStale
                                             error:error];
    if (!url) {
        return nil;
    }
    return [[ResolvedBookmark alloc] initWithURL:url isStale:isStale];
}

- (BOOL)startAccessing:(NSURL *)url {
    return [url startAccessingSecurityScopedResource];
}

- (void)stopAccessing:(NSURL *)url {
    [url stopAccessingSecurityScopedResource];
}
#endif

@end
