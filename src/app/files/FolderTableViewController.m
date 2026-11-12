#import "FolderTableViewController.h"

#if TARGET_OS_IOS
#import "FolderChildCell.h"
#import "UIButton+Bordered.h"

@implementation FolderTableViewController {
    Folder *_folder;
    Player *_player;
}

- (instancetype)initWithFolder:(Folder *)folder player:(Player *)player
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _folder = folder;
        _player = player;
        self.navigationItem.title = folder.name;
        self.navigationItem.largeTitleDisplayMode =
            UINavigationItemLargeTitleDisplayModeNever;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
            initWithCustomView:[UIButton borderedWithTitle:@"Find"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView registerClass:[FolderChildCell class]
           forCellReuseIdentifier:FolderChildCell.reuseIdentifier];
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section
{
    return _folder.children.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FolderChildCell *cell = [tableView
        dequeueReusableCellWithIdentifier:FolderChildCell.reuseIdentifier
                             forIndexPath:indexPath];
    id<FolderChild> child = _folder.children[indexPath.row];
    Player *player = _player;
    __weak typeof(self) weakSelf = self;
    [cell show:child
        onAdd:^{ [player.queue add:child]; }
        onOpen:^{ [weakSelf open:child]; }];
    return cell;
}

- (nullable NSIndexPath *)tableView:(UITableView *)tableView
           willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [_folder.children[indexPath.row] isKindOfClass:[Folder class]]
        ? indexPath
        : nil;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self open:_folder.children[indexPath.row]];
}

- (void)open:(id<FolderChild>)child
{
    if (![child isKindOfClass:[Folder class]]) {
        return;
    }
    FolderTableViewController *folderTable =
        [[FolderTableViewController alloc] initWithFolder:(Folder *)child
                                                   player:_player];
    [self.navigationController pushViewController:folderTable animated:YES];
}

@end
#endif
