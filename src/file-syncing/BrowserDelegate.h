#import <Foundation/Foundation.h>


@class FileShare;


@protocol BrowserDelegate <NSObject>

- (void)didFindFileShares:(NSArray<FileShare *> *)fileShares;

- (void)didFailToBrowseWithError:(NSError *)error;

@end
