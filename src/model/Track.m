#import "Track.h"

static BOOL isMusicFileExtension(NSString *pathExtension) {
    return [@[@"mp3", @"m4a"] containsObject:pathExtension.lowercaseString];
}

// The display name already omits the extension when the Finder hides it,
// so only strip an extension that is still present.
static NSString *trackName(NSString *displayName, NSString *pathExtension) {
    if (pathExtension.length == 0) {
        return displayName;
    }
    NSString *suffix = [@"." stringByAppendingString:pathExtension];
    NSRange range = [displayName rangeOfString:suffix
                                       options:NSCaseInsensitiveSearch | NSAnchoredSearch | NSBackwardsSearch];
    if (range.location == NSNotFound) {
        return displayName;
    }
    return [displayName substringToIndex:range.location];
}

@implementation Track

+ (NSString *)noAlbum {
    return @"(no album)";
}

+ (NSString *)noArtist {
    return @"(no artist)";
}

- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path {
    self = [super init];
    if (self) {
        _trackName = [trackName copy];
        _albumName = [albumName copy];
        _artistName = [artistName copy];
        _path = [path copy];
    }
    return self;
}

- (nullable instancetype)initWithDisplayName:(NSString *)displayName
                               pathExtension:(NSString *)pathExtension
                                        path:(NSString *)path
                                  folderName:(nullable NSString *)folderName
                            parentFolderName:(nullable NSString *)parentFolderName {
    if (!isMusicFileExtension(pathExtension)) {
        return nil;
    }
    return [self initWithTrackName:trackName(displayName, pathExtension)
                         albumName:folderName ?: Track.noAlbum
                        artistName:parentFolderName ?: Track.noArtist
                              path:path];
}

- (NSURL *)url {
    return [NSURL fileURLWithPath:_path isDirectory:NO];
}

- (NSString *)name {
    return _trackName;
}

- (NSArray<id<FolderChild>> *)children {
    return @[];
}

- (NSArray<Track *> *)trackDescendants {
    return @[self];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[Track class]]) {
        return NO;
    }
    Track *other = object;
    return [_trackName isEqualToString:other.trackName]
        && [_albumName isEqualToString:other.albumName]
        && [_artistName isEqualToString:other.artistName]
        && [_path isEqualToString:other.path];
}

- (NSUInteger)hash {
    NSUInteger hash = _trackName.hash;
    hash = hash * 31 + _albumName.hash;
    hash = hash * 31 + _artistName.hash;
    hash = hash * 31 + _path.hash;
    return hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Track(%@, %@, %@, %@)", _trackName, _albumName, _artistName, _path];
}

@end
