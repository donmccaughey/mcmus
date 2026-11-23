#import <Foundation/Foundation.h>

@protocol FileSyncingDelegate;
@protocol FileSystem;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FileSyncingID;

@interface FileSyncingClient
    : NSObject <NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property (readonly) dispatch_queue_t queue;

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                        delegate:(nullable id<FileSyncingDelegate>)delegate
                      fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)start;

@end

NS_ASSUME_NONNULL_END
