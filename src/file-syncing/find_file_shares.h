#import <Foundation/Foundation.h>
#import <dns_sd.h>


@class FileShare;


typedef void(find_file_shares_callback)(
    NSArray<FileShare *> *file_shares, DNSServiceErrorType error_code
);


void find_file_shares(
    dispatch_queue_t serial_queue,
    find_file_shares_callback callback,
    dispatch_queue_t callback_queue,
    int timeout_secs
);
