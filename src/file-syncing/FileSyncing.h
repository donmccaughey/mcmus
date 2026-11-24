#import <Foundation/Foundation.h>

#import "find_file_shares.h"
#import "get_url_for_file_share.h"


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
- (void)findFileSharesWithCallback:(find_file_shares_callback)callback
                           onQueue:(dispatch_queue_t)callbackQueue
                     withinSeconds:(NSUInteger)timeoutSeconds;

- (void)getURLForFileShare:(FileShare *)fileShare
              withCallback:(get_url_for_file_share_callback)callback
                   onQueue:(dispatch_queue_t)callbackQueue
             withinSeconds:(NSUInteger)timeoutSeconds;

@end


NS_ASSUME_NONNULL_END
