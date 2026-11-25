#import <Foundation/Foundation.h>


@class FileShare;

@protocol BrowserDelegate;
@protocol DNS;


NS_ASSUME_NONNULL_BEGIN


@interface Browser : NSObject

- (instancetype)initWithSerialQueue:(dispatch_queue_t)serialQueue
                            timeout:(NSTimeInterval)timeout
                           delegate:(id<BrowserDelegate>)delegate
                      delegateQueue:(dispatch_queue_t)delegateQueue
                                dns:(id<DNS>)dns;

- (instancetype)init NS_UNAVAILABLE;

- (void)start;

@end


NS_ASSUME_NONNULL_END
