#import "FilesTableStackController.h"

#if TARGET_OS_IOS
#import "FolderTableViewController.h"

@implementation FilesTableStackController {
    Player *_player;
    Folder *_Nullable _rootFolder;
}

- (instancetype)initWithPlayer:(Player *)player {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _player = player;
        [self drawOpaqueNavigationBar];
    }
    return self;
}

- (void)setRootFolder:(Folder *)folder {
    // Reloading the same library must not pop the user back to the root.
    if ([folder isEqual:_rootFolder]) {
        return;
    }
    _rootFolder = folder;
    FolderTableViewController *rootTable = [[FolderTableViewController alloc] initWithFolder:folder player:_player];
    [self setViewControllers:@[rootTable] animated:NO];
}

- (void)drawOpaqueNavigationBar {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.navigationBar.standardAppearance = appearance;
    // Without this the bar turns transparent while the table is scrolled
    // to its top.
    self.navigationBar.scrollEdgeAppearance = appearance;
}

@end
#endif
