#import "MusicLibrary.h"

#import "Folder.h"
#import "FolderChild.h"
#import "Track.h"


@implementation MusicLibrary


- (instancetype)initWithRootFolder:(Folder *)rootFolder;
{
    self = [super init];
    if (!self) return nil;

    _rootFolder = rootFolder;

    return self;
}


- (instancetype)init
{
    return [self initWithRootFolder:[Folder new]];
}


- (BOOL)isEmpty
{
    return _rootFolder.children.count == 0;
}


- (NSArray<Track *> *)getTracks;
{
    NSMutableArray<Track *> *tracks = [NSMutableArray new];
    NSMutableArray<id<FolderChild>> *stack =
        [[NSMutableArray alloc] initWithCapacity:_rootFolder.children.count];

    [stack addObject:_rootFolder];
    while (stack.count) {
        id<FolderChild> child = stack.lastObject;
        [stack removeLastObject];

        if ([child isKindOfClass:[Track class]]) {
            Track *track = child;
            [tracks addObject:track];
        } else if ([child isKindOfClass:[Folder class]]) {
            Folder *folder = child;
            for (int i = (int)folder.children.count - 1; i >= 0; --i) {
                [stack addObject:folder.children[i]];
            }
        } else {
            NSString *reason =
                [NSString stringWithFormat:@"Unexpected child %@ of class %@",
                    child, [child class]];
            @throw
                [NSException exceptionWithName:NSInternalInconsistencyException
                                        reason:reason
                                      userInfo:nil];
        }
    }

    return tracks;
}


@end
