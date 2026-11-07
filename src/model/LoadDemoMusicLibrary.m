#import "LoadDemoMusicLibrary.h"

#import "Folder.h"
#import "Track.h"

NSErrorDomain const LoadDemoErrorDomain = @"LoadDemoErrorDomain";

static NSString *_Nullable stringValue(NSDictionary *entry, NSString *key) {
    id value = entry[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSDictionary *_Nullable firstDirectoryEntry(id json) {
    if (![json isKindOfClass:[NSArray class]]) {
        return nil;
    }
    for (id entry in json) {
        if ([entry isKindOfClass:[NSDictionary class]] && [stringValue(entry, @"type") isEqualToString:@"directory"]) {
            return entry;
        }
    }
    return nil;
}

static LoadResult *emptyResult(NSError *error) {
    return [[LoadResult alloc] initWithLibrary:[[MusicLibrary alloc] init] errors:@[error]];
}

// The demo data has only names, so the localized display name rule cannot
// apply. The hidden file rule is applied by leading dot and the package
// rule by discarding `.itlp` directories, the only package in the data.
// Every track points at the bundled demo file so it is playable.
static NSArray<id<FolderChild>> *demoChildren(NSDictionary *entry,
                                              NSString *path,
                                              NSString *trackPath,
                                              NSString *_Nullable folderName,
                                              NSString *_Nullable parentFolderName) {
    NSMutableArray<id<FolderChild>> *children = [NSMutableArray array];
    id contents = entry[@"contents"];
    if (![contents isKindOfClass:[NSArray class]]) {
        return children;
    }
    for (id child in contents) {
        if (![child isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *name = stringValue(child, @"name");
        if (!name || [name hasPrefix:@"."]) {
            continue;
        }
        NSString *type = stringValue(child, @"type");
        NSString *childPath = [NSString stringWithFormat:@"%@/%@", path, name];
        if ([type isEqualToString:@"directory"]) {
            if ([name.pathExtension.lowercaseString isEqualToString:@"itlp"]) {
                continue;
            }
            NSArray<id<FolderChild>> *grandchildren = demoChildren(child, childPath, trackPath, name, folderName);
            [children addObject:[[Folder alloc] initWithPath:childPath name:name children:grandchildren]];
        } else if ([type isEqualToString:@"file"]) {
            Track *track = [[Track alloc] initWithDisplayName:name
                                                pathExtension:name.pathExtension
                                                         path:trackPath
                                                   folderName:folderName
                                             parentFolderName:parentFolderName];
            if (track) {
                [children addObject:track];
            }
        }
    }
    return FolderChildrenSortedByName(children);
}

LoadResult *loadDemoMusicLibrary(NSData *demoData, NSString *trackPath) {
    NSError *error;
    id json = [NSJSONSerialization JSONObjectWithData:demoData options:0 error:&error];
    if (!json) {
        return emptyResult(error);
    }
    NSDictionary *rootEntry = firstDirectoryEntry(json);
    if (!rootEntry) {
        return emptyResult([NSError errorWithDomain:LoadDemoErrorDomain
                                               code:LoadDemoErrorCodeNoDirectoryEntry
                                           userInfo:nil]);
    }
    NSString *rootPath = stringValue(rootEntry, @"name") ?: @"/";
    NSArray<id<FolderChild>> *children = demoChildren(rootEntry, rootPath, trackPath, nil, nil);
    Folder *rootFolder = [[Folder alloc] initWithPath:rootPath name:Folder.rootName children:children];
    return [[LoadResult alloc] initWithLibrary:[[MusicLibrary alloc] initWithRootFolder:rootFolder] errors:@[]];
}
