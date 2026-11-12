#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Track;

@protocol FolderChild <NSObject>

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSArray<id<FolderChild>> *children;
@property (nonatomic, readonly, copy) NSArray<Track *> *trackDescendants;

@end

NSArray<id<FolderChild>> *FolderChildrenSortedByName(
    NSArray<id<FolderChild>> *children);

NS_ASSUME_NONNULL_END
