#import "FileSystemReal.h"

#include <sys/clonefile.h>
#include <sys/stat.h>

// Prefetched by listDirectory so getFileInfo reads from the URL's cache
// instead of going back to disk for each entry.
static NSArray<NSURLResourceKey> *fileInfoKeys(void)
{
    return @[
        NSURLIsDirectoryKey, NSURLIsRegularFileKey, NSURLIsPackageKey,
        NSURLLocalizedNameKey
    ];
}

@implementation FileSystemReal

- (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error
{
    NSURL *url =
        [[NSFileManager defaultManager] URLForDirectory:NSMusicDirectory
                                               inDomain:NSUserDomainMask
                                      appropriateForURL:nil
                                                 create:YES
                                                  error:error];
    // Inside the App Sandbox the home directory is the app container, whose
    // Music entry is a symlink to the real ~/Music; resolve it so the user
    // sees the real path.
    return url.URLByResolvingSymlinksInPath;
}

- (nullable NSURL *)getApplicationSupportDirectoryURLAndReturnError:
    (NSError **)error
{
    return [[NSFileManager defaultManager]
          URLForDirectory:NSApplicationSupportDirectory
                 inDomain:NSUserDomainMask
        appropriateForURL:nil
                   create:YES
                    error:error];
}

- (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error
{
    return [[NSFileManager defaultManager] createDirectoryAtURL:url
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:error];
}

- (BOOL)excludeFromBackup:(NSURL *)url error:(NSError **)error
{
    return [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey
                           error:error];
}

- (nullable NSArray<NSURL *> *)listDirectory:(NSURL *)directory
                                       error:(NSError **)error
{
    return [[NSFileManager defaultManager]
          contentsOfDirectoryAtURL:directory
        includingPropertiesForKeys:fileInfoKeys()
                           options:NSDirectoryEnumerationSkipsHiddenFiles
                             error:error];
}

- (nullable FileSystemItemInfo *)getFileInfo:(NSURL *)url
                                       error:(NSError **)error
{
    NSDictionary<NSURLResourceKey, id> *values =
        [url resourceValuesForKeys:fileInfoKeys() error:error];
    if (!values) {
        return nil;
    }
    return [[FileSystemItemInfo alloc]
        initWithIsDirectory:[values[NSURLIsDirectoryKey] boolValue]
              isRegularFile:[values[NSURLIsRegularFileKey] boolValue]
                  isPackage:[values[NSURLIsPackageKey] boolValue]
              localizedName:values[NSURLLocalizedNameKey]];
}

- (BOOL)getSize:(unsigned long long *)size
         ofFile:(NSURL *)url
          error:(NSError **)error;
{
    struct stat status;
    errno = 0;
    if (0 == stat(url.fileSystemRepresentation, &status)) {
        *size = (unsigned long long)status.st_size;
        return YES;
    }
    if (error) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno
                                 userInfo:@{NSURLErrorKey: url}];
    }
    return NO;
}

static BOOL posixFailure(NSURL *url, NSError **error)
{
    if (error) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno
                                 userInfo:@{NSURLErrorKey: url}];
    }
    return NO;
}

- (BOOL)readFile:(NSURL *)url
          chunks:(void(NS_NOESCAPE ^)(const void *bytes, size_t length))chunk
           error:(NSError **)error;
{
    static const size_t bufferSize = 256 * 1024;
    int file = open(url.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
    if (file < 0) return posixFailure(url, error);

    void *buffer = malloc(bufferSize);
    BOOL ok = buffer != NULL;
    if (!ok) posixFailure(url, error);
    while (ok) {
        ssize_t count = read(file, buffer, bufferSize);
        if (count == 0) break;
        if (count < 0 && errno == EINTR) continue;
        if (count < 0) {
            ok = posixFailure(url, error);
        } else {
            chunk(buffer, (size_t)count);
        }
    }
    free(buffer);
    close(file);
    return ok;
}

- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error;
{
    return [[NSFileManager defaultManager] removeItemAtURL:URL error:error];
}

- (BOOL)cloneFile:(NSURL *)source
           toFile:(NSURL *)destination
            error:(NSError **)error;
{
    int flags = 0;
    char const *sourcePath = source.fileSystemRepresentation;
    char const *destinationPath = destination.fileSystemRepresentation;

    errno = 0;
    int result = clonefile(sourcePath, destinationPath, flags);
    if (0 == result) return YES;

    if (error) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno
                                 userInfo:nil];
    }
    return NO;
}

#if TARGET_OS_OSX
- (nullable NSData *)makeSecurityScopedBookmarkFor:(NSURL *)url
                                             error:(NSError **)error
{
    return [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
         includingResourceValuesForKeys:nil
                          relativeToURL:nil
                                  error:error];
}

- (nullable ResolvedBookmark *)resolveSecurityScopedBookmark:(NSData *)bookmark
                                                       error:(NSError **)error
{
    BOOL isStale = NO;
    NSURL *url = [NSURL
        URLByResolvingBookmarkData:bookmark
                           options:NSURLBookmarkResolutionWithSecurityScope
                     relativeToURL:nil
               bookmarkDataIsStale:&isStale
                             error:error];
    if (!url) {
        return nil;
    }
    return [[ResolvedBookmark alloc] initWithURL:url isStale:isStale];
}

- (BOOL)startAccessing:(NSURL *)url
{
    return [url startAccessingSecurityScopedResource];
}

- (void)stopAccessing:(NSURL *)url
{
    [url stopAccessingSecurityScopedResource];
}
#endif

@end
