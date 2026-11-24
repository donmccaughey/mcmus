#import "get_url_for_file_share.h"

#import "FileShare.h"


// alloc with `alloc_url_context()` and free with `free_url_context()`
struct url_context {
    FileShare *file_share;
    get_url_for_file_share_callback *callback;
    dispatch_queue_t callback_queue;
    DNSServiceRef service_ref;
    dispatch_block_t timeout_block;
};


static void free_url_context(struct url_context *url_context);

static void resolve_reply(
    DNSServiceRef service_ref,
    DNSServiceFlags flags,
    uint32_t interface_index,
    DNSServiceErrorType error_code,
    const char *full_service_domain_name,
    const char *target_host_name,
    uint16_t port_network_byte_order,
    uint16_t txt_record_len,
    const unsigned char *txt_record,
    void *context
);


static struct url_context *alloc_url_context(
    FileShare *file_share,
    get_url_for_file_share_callback *callback,
    dispatch_queue_t callback_queue
)
{
    struct url_context *url_context = calloc(1, sizeof(struct url_context));
    if (!url_context) return NULL;

    url_context->file_share = file_share;
    url_context->callback = callback;
    url_context->callback_queue = callback_queue;

    url_context->service_ref = NULL;

    dispatch_block_flags_t block_flags = 0;
    url_context->timeout_block = dispatch_block_create(block_flags, ^{
        get_url_for_file_share_callback *callback = url_context->callback;
        NSURL *url = nil;
        DNSServiceErrorType error_code = kDNSServiceErr_Timeout;
        dispatch_async(url_context->callback_queue, ^{
            callback(url, error_code);
        });
        free_url_context(url_context);
    });
    NSCAssert(url_context->timeout_block, @"Expected to create timeout_block");

    return url_context;
}


static void free_url_context(struct url_context *url_context)
{
    url_context->file_share = nil;
    url_context->callback_queue = nil;

    if (url_context->service_ref) {
        DNSServiceRefDeallocate(url_context->service_ref);
    }

    if (url_context->timeout_block) {
        dispatch_block_cancel(url_context->timeout_block);
    }
    url_context->timeout_block = nil;

    free(url_context);
}


void get_url_for_file_share(
    dispatch_queue_t serial_queue,
    FileShare *file_share,
    get_url_for_file_share_callback callback,
    dispatch_queue_t callback_queue,
    int timeout_secs
)
{
    dispatch_assert_queue(serial_queue);

    struct url_context *url_context =
        alloc_url_context(file_share, callback, callback_queue);
    if (!url_context) {
        dispatch_async(callback_queue, ^{
            NSURL *url = nil;
            callback(url, kDNSServiceErr_NoMemory);
        });
        return;
    }

    DNSServiceErrorType error_code;

    DNSServiceFlags flags = 0;
    error_code = DNSServiceResolve(
        &url_context->service_ref,
        flags,
        (uint32_t)file_share.interfaceIndex,
        file_share.serviceName.UTF8String,
        file_share.serviceType.UTF8String,
        file_share.domain.UTF8String,
        resolve_reply,
        url_context
    );
    if (kDNSServiceErr_NoError != error_code) {
        free_url_context(url_context);
        dispatch_async(callback_queue, ^{
            NSURL *url = nil;
            callback(url, error_code);
        });
        return;
    }

    error_code =
        DNSServiceSetDispatchQueue(url_context->service_ref, serial_queue);
    if (kDNSServiceErr_NoError != error_code) {
        free_url_context(url_context);
        dispatch_async(callback_queue, ^{
            NSURL *url = nil;
            callback(url, error_code);
        });
        return;
    }

    dispatch_time_t timeout_nanos = dispatch_time(
        DISPATCH_TIME_NOW, (int64_t)(timeout_secs * NSEC_PER_SEC)
    );
    dispatch_after(timeout_nanos, serial_queue, url_context->timeout_block);
}


static void resolve_reply(
    DNSServiceRef service_ref,
    DNSServiceFlags flags,
    uint32_t interface_index,
    DNSServiceErrorType error_code,
    const char *full_service_domain_name,
    const char *target_host_name,
    uint16_t port_network_byte_order,
    uint16_t txt_record_len,
    const unsigned char *txt_record,
    void *context
)
{
    struct url_context *url_context = context;
    if (kDNSServiceErr_NoError != error_code) {
        get_url_for_file_share_callback *callback = url_context->callback;
        NSURL *url = nil;
        DNSServiceErrorType error_code = kDNSServiceErr_Timeout;
        dispatch_async(url_context->callback_queue, ^{
            callback(url, error_code);
        });
        free_url_context(url_context);
        return;
    }

    NSString *host = [NSString stringWithCString:target_host_name
                                        encoding:NSASCIIStringEncoding];
    NSUInteger last_index = host.length - 1;
    if ('.' == [host characterAtIndex:last_index]) {
        host = [host substringToIndex:last_index];
    }
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = @"http";
    components.host = host;
    components.port =
        [NSNumber numberWithUnsignedShort:ntohs(port_network_byte_order)];

    get_url_for_file_share_callback *callback = url_context->callback;
    NSURL *url = components.URL;
    dispatch_async(url_context->callback_queue, ^{
        callback(url, kDNSServiceErr_NoError);
    });
    free_url_context(url_context);
}
