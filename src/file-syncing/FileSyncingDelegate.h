#import <Foundation/Foundation.h>


@class FileShare;
@class FileSyncing;


@protocol FileSyncingDelegate <NSObject>

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFindFileShares:(NSArray<FileShare *> *)fileShares;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToFindFileSharesWithError:(NSError *)error;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didResolveFileShare:(FileShare *)fileShare
                withURL:(NSURL *)url;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToResolveFileShare:(FileShare *)fileShare
                    withError:(NSError *)error;

@end
