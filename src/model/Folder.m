#import "Folder.h"

#import "Track.h"

// [nil isEqual:nil] is NO, so nullable properties need their own comparison.
static BOOL equalOrBothNil(id _Nullable a, id _Nullable b) {
    return a == b || [a isEqual:b];
}

@implementation Folder

+ (NSString *)rootName {
    return @"Files";
}

- (instancetype)initWithPath:(nullable NSString *)path
                        name:(NSString *)name
                    children:(NSArray<id<FolderChild>> *)children {
    self = [super init];
    if (self) {
        _path = [path copy];
        _name = [name copy];
        _children = [children copy];
    }
    return self;
}

- (instancetype)init {
    return [self initWithPath:nil name:Folder.rootName children:@[]];
}

- (NSArray<Track *> *)trackDescendants {
    NSMutableArray<Track *> *tracks = [NSMutableArray array];
    for (id<FolderChild> child in _children) {
        [tracks addObjectsFromArray:child.trackDescendants];
    }
    return tracks;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[Folder class]]) {
        return NO;
    }
    Folder *other = object;
    if (!equalOrBothNil(_path, other.path)
        || ![_name isEqualToString:other.name]
        || _children.count != other.children.count) {
        return NO;
    }
    for (NSUInteger i = 0; i < _children.count; i++) {
        if (![_children[i] isEqual:other.children[i]]) {
            return NO;
        }
    }
    return YES;
}

// Shallow, so hashing a tree does not walk it; isEqual still does.
- (NSUInteger)hash {
    NSUInteger hash = _path.hash;
    hash = hash * 31 + _name.hash;
    hash = hash * 31 + _children.count;
    return hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Folder(%@, %@, %lu children)",
            _path ?: @"nil", _name, (unsigned long)_children.count];
}

@end
