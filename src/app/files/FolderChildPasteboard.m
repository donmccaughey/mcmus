#import "FolderChildPasteboard.h"

#if TARGET_OS_OSX
#import "Folder.h"
#import "Track.h"

NSPasteboardType const FolderChildPasteboardType =
    @"cc.donm.mcmus.folder-child";

static NSString *const kindKey = @"kind";
static NSString *const pathKey = @"path";
static NSString *const nameKey = @"name";
static NSString *const childrenKey = @"children";
static NSString *const trackNameKey = @"trackName";
static NSString *const albumNameKey = @"albumName";
static NSString *const artistNameKey = @"artistName";

static NSString *const folderKind = @"folder";
static NSString *const trackKind = @"track";

// The model classes stay free of coding; drags are app-local, so this
// archive format answers to nothing else.
@interface FolderChildPayload : NSObject <NSSecureCoding>

@property (nonatomic, readonly) id<FolderChild> child;

- (instancetype)initWithChild:(id<FolderChild>)child NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

static NSArray<FolderChildPayload *> *payloadsForChildren(
    NSArray<id<FolderChild>> *children)
{
    NSMutableArray<FolderChildPayload *> *payloads =
        [NSMutableArray arrayWithCapacity:children.count];
    for (id<FolderChild> child in children) {
        [payloads addObject:[[FolderChildPayload alloc] initWithChild:child]];
    }
    return payloads;
}

static NSArray<id<FolderChild>> *childrenOfPayloads(
    NSArray<FolderChildPayload *> *payloads)
{
    NSMutableArray<id<FolderChild>> *children =
        [NSMutableArray arrayWithCapacity:payloads.count];
    for (FolderChildPayload *payload in payloads) {
        [children addObject:payload.child];
    }
    return children;
}

@implementation FolderChildPayload

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithChild:(id<FolderChild>)child
{
    self = [super init];
    if (self) {
        _child = child;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([_child isKindOfClass:[Folder class]]) {
        Folder *folder = (Folder *)_child;
        [coder encodeObject:folderKind forKey:kindKey];
        [coder encodeObject:folder.path forKey:pathKey];
        [coder encodeObject:folder.name forKey:nameKey];
        [coder encodeObject:payloadsForChildren(folder.children)
                     forKey:childrenKey];
    } else if ([_child isKindOfClass:[Track class]]) {
        Track *track = (Track *)_child;
        [coder encodeObject:trackKind forKey:kindKey];
        [coder encodeObject:track.trackName forKey:trackNameKey];
        [coder encodeObject:track.albumName forKey:albumNameKey];
        [coder encodeObject:track.artistName forKey:artistNameKey];
        [coder encodeObject:track.path forKey:pathKey];
    }
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *kind = [coder decodeObjectOfClass:[NSString class]
                                         forKey:kindKey];
    if ([kind isEqualToString:folderKind]) {
        NSString *name = [coder decodeObjectOfClass:[NSString class]
                                             forKey:nameKey];
        NSArray<FolderChildPayload *> *children =
            [coder decodeArrayOfObjectsOfClass:[FolderChildPayload class]
                                        forKey:childrenKey];
        if (!name || !children) {
            return nil;
        }
        NSString *path = [coder decodeObjectOfClass:[NSString class]
                                             forKey:pathKey];
        return
            [self initWithChild:[[Folder alloc]
                                    initWithPath:path
                                            name:name
                                        children:childrenOfPayloads(children)]];
    } else if ([kind isEqualToString:trackKind]) {
        NSString *trackName = [coder decodeObjectOfClass:[NSString class]
                                                  forKey:trackNameKey];
        NSString *albumName = [coder decodeObjectOfClass:[NSString class]
                                                  forKey:albumNameKey];
        NSString *artistName = [coder decodeObjectOfClass:[NSString class]
                                                   forKey:artistNameKey];
        NSString *path = [coder decodeObjectOfClass:[NSString class]
                                             forKey:pathKey];
        if (!trackName || !albumName || !artistName || !path) {
            return nil;
        }
        return [self initWithChild:[[Track alloc] initWithTrackName:trackName
                                                          albumName:albumName
                                                         artistName:artistName
                                                               path:path]];
    } else {
        return nil;
    }
}

@end

@implementation FolderChildPasteboard

+ (NSPasteboardItem *)pasteboardItemForChild:(id<FolderChild>)child
{
    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
    FolderChildPayload *payload =
        [[FolderChildPayload alloc] initWithChild:child];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:payload
                                         requiringSecureCoding:YES
                                                         error:NULL];
    if (data) {
        [item setData:data forType:FolderChildPasteboardType];
    }
    return item;
}

+ (nullable id<FolderChild>)childInItem:(NSPasteboardItem *)item
{
    NSData *data = [item dataForType:FolderChildPasteboardType];
    if (!data) {
        return nil;
    }
    FolderChildPayload *payload =
        [NSKeyedUnarchiver unarchivedObjectOfClass:[FolderChildPayload class]
                                          fromData:data
                                             error:NULL];
    return payload.child;
}

+ (NSArray<id<FolderChild>> *)childrenInPasteboard:(NSPasteboard *)pasteboard
{
    NSMutableArray<id<FolderChild>> *children = [NSMutableArray array];
    for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
        id<FolderChild> child = [self childInItem:item];
        if (child) {
            [children addObject:child];
        }
    }
    return children;
}

@end
#endif
