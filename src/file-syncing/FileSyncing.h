#import <Foundation/Foundation.h>


@protocol DNS;
@protocol FileSyncingDelegate;
@protocol FileSystem;

@class FileShare;


NS_ASSUME_NONNULL_BEGIN


@interface FileSyncing : NSObject

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(id<FileSyncingDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                      fileSystem:(id<FileSystem>)fileSystem
                             dns:(id<DNS>)dns NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)findFileSharesWithTimeout:(NSTimeInterval)timeout;

- (void)resolveFileShare:(FileShare *)fileShare
             withTimeout:(NSTimeInterval)timeout;

@end


NS_ASSUME_NONNULL_END
