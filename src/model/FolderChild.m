#import "FolderChild.h"

NSArray<id<FolderChild>> *FolderChildrenSortedByName(NSArray<id<FolderChild>> *children) {
    return [children sortedArrayWithOptions:NSSortStable
                            usingComparator:^NSComparisonResult(id<FolderChild> a, id<FolderChild> b) {
                                return [a.name localizedStandardCompare:b.name];
                            }];
}
