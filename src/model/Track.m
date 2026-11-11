#import "Track.h"

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

+ (BOOL)isMusicFileExtension:(NSString *)pathExtension;
{
    return [@[@"mp3", @"m4a"] containsObject:pathExtension.lowercaseString];
}

- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path
                             size:(unsigned long long)size
                         fileHash:(NSUInteger)fileHash;
{
    self = [super init];
    if ( ! self) return nil;

    _trackName = [trackName copy];
    _albumName = [albumName copy];
    _artistName = [artistName copy];
    _path = [path copy];
    _size = size;
    _fileHash = fileHash;

    return self;
}

- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path
                             size:(unsigned long long)size;
{
    return [self initWithTrackName:trackName
                         albumName:albumName
                        artistName:artistName
                              path:path
                              size:size
                          fileHash:0];
}

- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path;
{
    return [self initWithTrackName:trackName albumName:albumName artistName:artistName path:path size:0];
}

- (nullable instancetype)initWithDisplayName:(NSString *)displayName
                               pathExtension:(NSString *)pathExtension
                                        path:(NSString *)path
                                  folderName:(nullable NSString *)folderName
                            parentFolderName:(nullable NSString *)parentFolderName
                                        size:(unsigned long long)size
                                    fileHash:(NSUInteger)fileHash;
{
    if ( ! [Track isMusicFileExtension:pathExtension]) return nil;
    return [self initWithTrackName:trackName(displayName, pathExtension)
                         albumName:folderName ?: Track.noAlbum
                        artistName:parentFolderName ?: Track.noArtist
                              path:path
                              size:size
                          fileHash:fileHash];
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
    return [_path isEqualToString:other.path];
}

- (NSUInteger)hash {
    return _path.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Track(%@, %@, %@, %@, %llu, 0x%016lx)",
                                      _trackName, _albumName, _artistName, _path, _size, (unsigned long)_fileHash];
}

@end
