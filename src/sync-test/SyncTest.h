#import <Foundation/Foundation.h>


@protocol Clock;
@protocol DNS;
@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


@interface SyncTest : NSObject

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                     serialQueue:(dispatch_queue_serial_t)serialQueue
                           clock:(id<Clock>)clock
                             dns:(id<DNS>)dns
                      fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)run;

@end


NS_ASSUME_NONNULL_END
