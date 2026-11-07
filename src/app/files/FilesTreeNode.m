#import "FilesTreeNode.h"

#if TARGET_OS_OSX
#import "Folder.h"

@implementation FilesTreeNode

- (instancetype)initWithChild:(id<FolderChild>)child {
    self = [super init];
    if (self) {
        _child = child;
        NSMutableArray<FilesTreeNode *> *children = [NSMutableArray arrayWithCapacity:child.children.count];
        for (id<FolderChild> grandchild in child.children) {
            [children addObject:[[FilesTreeNode alloc] initWithChild:grandchild]];
        }
        _children = children;
    }
    return self;
}

- (NSString *)name {
    return _child.name;
}

- (BOOL)isExpandable {
    return [_child isKindOfClass:[Folder class]];
}

- (NSString *)systemImage {
    return [_child isKindOfClass:[Folder class]] ? @"folder" : @"music.note";
}

@end
#endif
