#import <Foundation/Foundation.h>

#import "Folder.h"

NS_ASSUME_NONNULL_BEGIN

@interface MusicLibrary : NSObject

@property (nonatomic, readonly) Folder *rootFolder;
@property (nonatomic, readonly) BOOL isEmpty;

- (instancetype)initWithRootFolder:(Folder *)rootFolder NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
