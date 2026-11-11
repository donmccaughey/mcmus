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
    return [_trackName isEqualToString:other.trackName]
        && [_albumName isEqualToString:other.albumName]
        && [_artistName isEqualToString:other.artistName]
        && [_path isEqualToString:other.path]
        && _size == other.size
        && _fileHash == other.fileHash;
}

- (NSUInteger)hash {
    NSUInteger hash = _trackName.hash;
    hash = hash * 31 + _albumName.hash;
    hash = hash * 31 + _artistName.hash;
    hash = hash * 31 + _path.hash;
    hash = hash * 31 + (NSUInteger)_size;
    hash = hash * 31 + _fileHash;
    return hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Track(%@, %@, %@, %@, %llu, 0x%016lx)",
                                      _trackName, _albumName, _artistName, _path, _size, (unsigned long)_fileHash];
}

@end
