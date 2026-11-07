#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

extern NSPasteboardType const FolderChildPasteboardType;

@interface FolderChildPasteboard : NSObject

+ (NSPasteboardItem *)pasteboardItemForChild:(id<FolderChild>)child;
+ (nullable id<FolderChild>)childInItem:(NSPasteboardItem *)item;
+ (NSArray<id<FolderChild>> *)childrenInPasteboard:(NSPasteboard *)pasteboard;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
