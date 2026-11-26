#import <Foundation/Foundation.h>


@protocol Clock;
@protocol DNS;
@protocol FileSyncingDelegate;
@protocol FileSystem;

@class FileShare;
@class Manifest;


NS_ASSUME_NONNULL_BEGIN


// The error code is the HTTP status code of the response.
extern NSErrorDomain const HTTPStatusErrorDomain;


@interface FileSyncing : NSObject

@property (nonatomic, readonly) Manifest *localManifest;
@property (nonatomic, readonly, nullable) Manifest *serverManifest;

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(id<FileSyncingDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                      fileSystem:(id<FileSystem>)fileSystem
                             dns:(id<DNS>)dns
                           clock:(id<Clock>)clock NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)findFileSharesWithTimeout:(NSTimeInterval)timeout;

- (void)syncWithFileShare:(FileShare *)fileShare;

@end


NS_ASSUME_NONNULL_END
