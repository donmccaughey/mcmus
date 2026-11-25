#import <Foundation/Foundation.h>

#import "find_file_shares.h"


@protocol FileSyncingDelegate;
@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


@interface FileSyncing : NSObject

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(id<FileSyncingDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                      fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)findFileSharesWithCallback:(find_file_shares_callback)callback
                           onQueue:(dispatch_queue_t)callbackQueue
                     withinSeconds:(NSUInteger)timeoutSeconds;

- (void)resolveFileShare:(FileShare *)fileShare
             withTimeout:(NSTimeInterval)timeout;

@end


NS_ASSUME_NONNULL_END
