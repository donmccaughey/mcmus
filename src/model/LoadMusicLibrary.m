#import "LoadMusicLibrary.h"

#import "Folder.h"
#import "Track.h"

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
            [children addObject:[[Track alloc] initWithDisplayName:name
                                                     pathExtension:url.pathExtension
                                                              path:url.path
                                                        folderName:folderName
                                                  parentFolderName:parentFolderName
                                                              size:size]];
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
