#import <Foundation/Foundation.h>
#import <dns_sd.h>


struct file_share;


typedef void(find_file_shares_callback)(
    struct file_share *file_shares,
    NSUInteger count,
    DNSServiceErrorType error_code
);


struct file_share {
    uint32_t interface_index;
    char service_name[192];
    char service_type[64];
    char domain[256];
};


void find_file_shares(
    dispatch_queue_t serial_queue,
    struct file_share *file_shares,
    int capacity,
    find_file_shares_callback callback,
    dispatch_queue_t callback_queue,
    int timeout_secs
);
