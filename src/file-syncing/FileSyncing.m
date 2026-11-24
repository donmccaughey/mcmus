#import "FileSyncing.h"


@implementation FileSyncing {
    dispatch_queue_t _queue;
}


- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                      fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _queue =
        dispatch_queue_create(self.className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)findFileShares:(struct file_share *)fileShares
          withCapacity:(NSUInteger)capacity
           andCallback:(find_file_shares_callback)callback
               onQueue:(dispatch_queue_t)callbackQueue
         withinSeconds:(NSUInteger)timeoutSeconds;
{
    NSAssert(capacity < INT_MAX, @"Expected capacity less than INT_MAX");
    NSAssert(
        timeoutSeconds < INT_MAX, @"Expected timeoutSeconds less than INT_MAX");
    dispatch_async(_queue, ^{
        find_file_shares(self->_queue, fileShares, (int)capacity, callback,
            callbackQueue, (int)timeoutSeconds);
    });
}


@end
