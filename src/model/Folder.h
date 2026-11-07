#import <Foundation/Foundation.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

@interface Folder : NSObject <FolderChild>

@property (nonatomic, readonly, copy, nullable) NSString *path;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSArray<id<FolderChild>> *children;

@property (class, nonatomic, readonly) NSString *rootName;

- (instancetype)initWithPath:(nullable NSString *)path
                        name:(NSString *)name
                    children:(NSArray<id<FolderChild>> *)children NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
