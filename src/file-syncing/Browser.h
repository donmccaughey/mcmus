#import <Foundation/Foundation.h>


@class FileShare;

@protocol BrowserDelegate;
@protocol Clock;
@protocol DNS;


NS_ASSUME_NONNULL_BEGIN


@interface Browser : NSObject

- (instancetype)initWithSerialQueue:(dispatch_queue_t)serialQueue
                            timeout:(NSTimeInterval)timeout
                           delegate:(id<BrowserDelegate>)delegate
                      delegateQueue:(dispatch_queue_t)delegateQueue
                                dns:(id<DNS>)dns
                              clock:(id<Clock>)clock;

- (instancetype)init NS_UNAVAILABLE;

- (void)start;

@end


NS_ASSUME_NONNULL_END
