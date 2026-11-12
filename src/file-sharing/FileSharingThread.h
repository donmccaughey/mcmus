#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>

#import "FileSharingService.h"


@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


@interface FileSharingThread : NSThread <FileSharingService>

- (instancetype)initWithFileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTarget:(id)target
                      selector:(SEL)selector
                        object:(nullable id)argument NS_UNAVAILABLE;
- (instancetype)initWithBlock:(void (^)(void))block NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END


#endif
