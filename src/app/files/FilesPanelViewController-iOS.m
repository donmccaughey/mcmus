#import "FilesPanelViewController-iOS.h"

#if TARGET_OS_IOS
#import "EmptyStateView-iOS.h"
#import "FilesTableStackController.h"
#import "PanelView-iOS.h"
#import "UIButton+Bordered.h"

// The panel title only shows while the library is empty and there is
// nothing to find; the active find button is the folder table's.
static UIButton *makePlaceholderFindButton(void)
{
    UIButton *findButton = [UIButton borderedWithTitle:@"Find"];
    findButton.enabled = NO;
    return findButton;
}

@implementation FilesPanelViewController {
    MusicLibraryStore *_store;
    EmptyStateView *_emptyFilesView;
    FilesTableStackController *_filesTableStack;
    PanelView *_panelView;
}

- (instancetype)initWithStore:(MusicLibraryStore *)store player:(Player *)player
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _emptyFilesView = [[EmptyStateView alloc] initWithTitle:@"No music"
                                                    systemImage:@"folder"
                                                    description:@""];
        _filesTableStack =
            [[FilesTableStackController alloc] initWithPlayer:player];
        _panelView =
            [[PanelView alloc] initWithTitle:@"Files"
                                   accessory:makePlaceholderFindButton()];
    }
    return self;
}

- (void)loadView
{
    self.view = _panelView;
    [self addChildViewController:_filesTableStack];
    [_filesTableStack didMoveToParentViewController:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(update)
               name:MusicLibraryStore.libraryDidChangeNotification
             object:_store];
    [self update];
}

- (void)update
{
    MusicLibrary *library = _store.library;
    if (library.isEmpty) {
        _emptyFilesView.descriptionText = _store.loadDidFail
            ? @"The music library did not load."
            : @"The music library is empty.";
        _panelView.showsTitle = YES;
        [_panelView setContent:_emptyFilesView];
    } else {
        // The root folder table's navigation bar already shows the
        // "Files" title and a find button, so the panel title would
        // duplicate them.
        _panelView.showsTitle = NO;
        [_filesTableStack setRootFolder:library.rootFolder];
        [_panelView setContent:_filesTableStack.view];
    }
}

@end
#endif
