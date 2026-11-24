#import <Foundation/Foundation.h>
#import <dns_sd.h>


struct file_share;


typedef void(get_url_for_file_share_callback)(
    NSURL *url, DNSServiceErrorType error_code
);


void get_url_for_file_share(
    dispatch_queue_t serial_queue,
    struct file_share const *file_share,
    get_url_for_file_share_callback callback,
    dispatch_queue_t callback_queue,
    int timeout_secs
);
