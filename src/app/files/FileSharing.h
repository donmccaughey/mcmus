#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>

#import "FileSystem.h"
#import "MusicLibraryStore.h"


NS_ASSUME_NONNULL_BEGIN


@interface FileSharing : NSObject

@property (class, nonatomic, readonly) NSNotificationName didChangeNotification;

@property (nonatomic, readonly) BOOL isSharing;
@property (nonatomic, readonly, nullable) NSError *error;

- (instancetype)initWithStore:(MusicLibraryStore *)store
                   fileSystem:(id<FileSystem>)fileSystem NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithStore:(MusicLibraryStore *)store;
- (instancetype)init NS_UNAVAILABLE;

- (void)start;
- (void)stop;

@end


NS_ASSUME_NONNULL_END


#endif
