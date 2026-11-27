#import <Foundation/Foundation.h>


@class FileShare;

@protocol FileShareFinderDelegate;
@protocol Clock;
@protocol DNS;


NS_ASSUME_NONNULL_BEGIN


@interface FileShareFinder : NSObject

- (instancetype)initWithTimeout:(NSTimeInterval)timeout
                    serialQueue:(dispatch_queue_serial_t)serialQueue
                       delegate:(id<FileShareFinderDelegate>)delegate
                  delegateQueue:(dispatch_queue_t)delegateQueue
                            dns:(id<DNS>)dns
                          clock:(id<Clock>)clock NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)start;

@end


NS_ASSUME_NONNULL_END
