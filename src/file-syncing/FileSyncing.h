#import <Foundation/Foundation.h>


@protocol Clock;
@protocol DNS;
@protocol FileSyncingDelegate;
@protocol FileSystem;

@class FileShare;
@class Manifest;


NS_ASSUME_NONNULL_BEGIN


@interface FileSyncing : NSObject

@property (nonatomic, readonly) Manifest *localManifest;
@property (nonatomic, readonly, nullable) Manifest *serverManifest;

- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                     serialQueue:(dispatch_queue_serial_t)serialQueue
                        delegate:(id<FileSyncingDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue
                           clock:(id<Clock>)clock
                             dns:(id<DNS>)dns
                      fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)syncWithFileShare:(FileShare *)fileShare;

@end


NS_ASSUME_NONNULL_END
