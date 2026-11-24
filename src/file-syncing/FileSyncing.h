#import "file_share.h"
#import <Foundation/Foundation.h>


@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


@interface FileSyncing : NSObject

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                      fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

// The caller owns `fileShares` memory
- (void)findFileShares:(struct file_share *)fileShares
          withCapacity:(NSUInteger)capacity
           andCallback:(find_file_shares_callback)callback
               onQueue:(dispatch_queue_t)callbackQueue
         withinSeconds:(NSUInteger)timeoutSeconds;

@end


NS_ASSUME_NONNULL_END
