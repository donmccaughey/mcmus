#import <Foundation/Foundation.h>


@class FileShare;


@protocol FileShareFinderDelegate <NSObject>

- (void)didFindFileShares:(NSArray<FileShare *> *)fileShares;

- (void)didFailToBrowseWithError:(NSError *)error;

@end
