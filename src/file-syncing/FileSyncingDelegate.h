#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FileSyncingDelegate <NSObject>

- (void)syncDidStart;

- (void)syncDidComplete;

- (void)syncDidFailWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
