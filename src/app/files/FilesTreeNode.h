#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <Foundation/Foundation.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

// NSOutlineView keys expansion state and drags on item identity, but Folder
// and Track compare by value, so the tree gets identity-only stand-ins.
@interface FilesTreeNode : NSObject

@property (nonatomic, readonly) id<FolderChild> child;
@property (nonatomic, readonly, copy) NSArray<FilesTreeNode *> *children;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) BOOL isExpandable;
@property (nonatomic, readonly, copy) NSString *systemImage;

- (instancetype)initWithChild:(id<FolderChild>)child NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
