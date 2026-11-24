#import "FileSyncing.h"


@implementation FileSyncing {
    dispatch_queue_t _serial_queue;
}


- (instancetype)initWithMusicDir:(NSURL *)musicDir
                      workingDir:(NSURL *)workingDir
                    manifestPath:(NSURL *)manifestPath
                      fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _serial_queue =
        dispatch_queue_create(self.className.UTF8String, DISPATCH_QUEUE_SERIAL);

    return self;
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (void)findFileSharesWithCallback:(find_file_shares_callback)callback
                           onQueue:(dispatch_queue_t)callbackQueue
                     withinSeconds:(NSUInteger)timeoutSeconds;
{
    NSAssert(
        timeoutSeconds < INT_MAX, @"Expected timeoutSeconds less than INT_MAX"
    );
    dispatch_async(_serial_queue, ^{
        find_file_shares(
            self->_serial_queue, callback, callbackQueue, (int)timeoutSeconds
        );
    });
}


- (void)getURLForFileShare:(FileShare *)fileShare
              withCallback:(get_url_for_file_share_callback)callback
                   onQueue:(dispatch_queue_t)callbackQueue
             withinSeconds:(NSUInteger)timeoutSeconds;
{
    NSAssert(
        timeoutSeconds < INT_MAX, @"Expected timeoutSeconds less than INT_MAX"
    );
    dispatch_async(_serial_queue, ^{
        get_url_for_file_share(
            self->_serial_queue,
            fileShare,
            callback,
            callbackQueue,
            (int)timeoutSeconds
        );
    });
}


@end
