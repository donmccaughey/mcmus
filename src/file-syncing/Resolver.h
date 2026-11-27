#import <Foundation/Foundation.h>


@class FileShare;

@protocol Clock;
@protocol DNS;
@protocol ResolverDelegate;


NS_ASSUME_NONNULL_BEGIN


@interface Resolver : NSObject

- (instancetype)initWithFileShare:(FileShare *)fileShare
                      serialQueue:(dispatch_queue_serial_t)serialQueue
                          timeout:(NSTimeInterval)timeout
                         delegate:(id<ResolverDelegate>)delegate
                    delegateQueue:(dispatch_queue_t)delegateQueue
                              dns:(id<DNS>)dns
                            clock:(id<Clock>)clock NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)start;

@end


NS_ASSUME_NONNULL_END
