#import "MusicLibrary.h"

@implementation MusicLibrary

- (instancetype)initWithRootFolder:(Folder *)rootFolder {
    self = [super init];
    if (self) {
        _rootFolder = rootFolder;
    }
    return self;
}

- (instancetype)init {
    return [self initWithRootFolder:[[Folder alloc] init]];
}

- (BOOL)isEmpty {
    return _rootFolder.children.count == 0;
}

@end
