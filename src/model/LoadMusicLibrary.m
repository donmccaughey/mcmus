#import "LoadMusicLibrary.h"

#import <assert.h>

#import "Folder.h"
#import "Track.h"
#import "xxhash.h"

NSErrorDomain const LoadMusicLibraryErrorDomain = @"LoadMusicLibraryErrorDomain";

static_assert(sizeof(XXH64_hash_t) == sizeof(NSUInteger),
              "Track stores the XXH3-64 digest in an NSUInteger");

// Trackless folders are pruned bottom-up, so any surviving child is either a
// track or a folder that contains tracks somewhere below it.
static BOOL hasTrackDescendants(NSArray<id<FolderChild>> *children) {
    return children.count > 0;
}

static BOOL readTrackSize(NSURL *url,
                          LoadOptions options,
                          id<FileSystem> fileSystem,
                          unsigned long long *size,
                          NSError **error) {
    *size = 0;
    if ( ! (options & LoadOptionsTrackSize)) return YES;
    return [fileSystem getSize:size ofFile:url error:error];
}

static NSError *hashFailed(NSURL *url) {
    return [NSError errorWithDomain:LoadMusicLibraryErrorDomain
                               code:LoadMusicLibraryErrorCodeHashFailed
                           userInfo:@{NSFilePathErrorKey: url.path}];
}

static BOOL hashFile(NSURL *url,
                     id<FileSystem> fileSystem,
                     XXH3_state_t *state,
                     NSUInteger *fileHash,
                     NSError **error) {
    if (XXH_OK != XXH3_64bits_reset(state)) {
        *error = hashFailed(url);
        return NO;
    }
    __block XXH_errorcode updated = XXH_OK;
    BOOL read = [fileSystem readFile:url
                              chunks:^(const void *bytes, size_t length) {
        if (XXH_OK == updated) updated = XXH3_64bits_update(state, bytes, length);
    }
                               error:error];
    if ( ! read) return NO;
    if (XXH_OK != updated) {
        *error = hashFailed(url);
        return NO;
    }
    *fileHash = XXH3_64bits_digest(state);
    return YES;
}

// A track whose hash cannot be gathered stays in the library with the
// "not gathered" hash of zero.
static NSUInteger readTrackHash(NSURL *url,
                                LoadOptions options,
                                id<FileSystem> fileSystem,
                                NSMutableArray<NSError *> *errors) {
    if ( ! (options & LoadOptionsTrackHash)) return 0;
    XXH3_state_t *state = XXH3_createState();
    if ( ! state) {
        [errors addObject:hashFailed(url)];
        return 0;
    }
    NSUInteger fileHash = 0;
    NSError *error;
    if ( ! hashFile(url, fileSystem, state, &fileHash, &error)) {
        [errors addObject:error];
        fileHash = 0;
    }
    XXH3_freeState(state);
    return fileHash;
}

// folderName and parentFolderName are nil for the root folder and its
// children respectively, which is how tracks fall back to "(no album)" and
// "(no artist)".
static NSArray<id<FolderChild>> *loadChildren(NSURL *directory,
                                              NSString *_Nullable folderName,
                                              NSString *_Nullable parentFolderName,
                                              LoadOptions options,
                                              id<FileSystem> fileSystem,
                                              NSMutableArray<NSError *> *errors) {
    NSError *error;
    NSArray<NSURL *> *contents = [fileSystem listDirectory:directory error:&error];
    if (!contents) {
        [errors addObject:error];
        return @[];
    }

    NSMutableArray<id<FolderChild>> *children = [NSMutableArray array];
    for (NSURL *url in contents) {
        FileSystemItemInfo *info = [fileSystem getFileInfo:url error:&error];
        if (!info) {
            [errors addObject:error];
            continue;
        }
        // Packages such as Apple Music's `Music Library.musiclibrary` are
        // directories on disk but not music directories.
        if (info.isPackage) {
            continue;
        }
        NSString *name = info.localizedName ?: url.lastPathComponent;
        if (info.isDirectory) {
            NSArray<id<FolderChild>> *grandchildren = loadChildren(url, name, folderName, options, fileSystem, errors);
            if (hasTrackDescendants(grandchildren)) {
                [children addObject:[[Folder alloc] initWithPath:url.path name:name children:grandchildren]];
            }
        } else if (info.isRegularFile && [Track isMusicFileExtension:url.pathExtension]) {
            unsigned long long size;
            if ( ! readTrackSize(url, options, fileSystem, &size, &error)) {
                [errors addObject:error];
                continue;
            }
            NSUInteger fileHash = readTrackHash(url, options, fileSystem, errors);
            [children addObject:[[Track alloc] initWithDisplayName:name
                                                     pathExtension:url.pathExtension
                                                              path:url.path
                                                        folderName:folderName
                                                  parentFolderName:parentFolderName
                                                              size:size
                                                          fileHash:fileHash]];
        }
    }
    return FolderChildrenSortedByName(children);
}

LoadResult *loadMusicLibrary(NSURL *musicRootDirectory,
                             LoadOptions options,
                             id<FileSystem> fileSystem) {
    NSMutableArray<NSError *> *errors = [NSMutableArray array];
    NSArray<id<FolderChild>> *children = loadChildren(musicRootDirectory, nil, nil, options, fileSystem, errors);
    Folder *rootFolder = [[Folder alloc] initWithPath:musicRootDirectory.path name:Folder.rootName children:children];
    return [[LoadResult alloc] initWithLibrary:[[MusicLibrary alloc] initWithRootFolder:rootFolder] errors:errors];
}
