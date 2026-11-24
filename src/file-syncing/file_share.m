#import "file_share.h"


// alloc with `alloc_find_context()` and free with `free_find_context()`
struct find_context {
    struct file_share *file_shares;
    int count;
    int capacity;
    find_file_shares_callback *callback;
    dispatch_queue_t callback_queue;
    DNSServiceRef service_ref;
    dispatch_block_t timeout_block;
};

// alloc with `alloc_url_context()` and free with `free_url_context()`
struct url_context {
    struct file_share const *file_share;
    get_url_for_file_share_callback *callback;
    dispatch_queue_t callback_queue;
    DNSServiceRef service_ref;
    dispatch_block_t timeout_block;
};


static void complete_find_file_shares(
    struct find_context *find_context, DNSServiceErrorType error_code
);

static void free_find_context(struct find_context *find_context);

static void free_url_context(struct url_context *url_context);

static int matching_file_share(
    struct file_share *file_shares,
    int count,
    uint32_t interface_index,
    char const *service_name,
    char const *service_type,
    char const *domain
);

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


static struct find_context *alloc_find_context(
    struct file_share *file_shares,
    int capacity,
    find_file_shares_callback callback,
    dispatch_queue_t callback_queue
)
{
    struct find_context *find_context = calloc(1, sizeof(struct find_context));
    if (!find_context) return NULL;

    find_context->file_shares = file_shares;
    find_context->count = 0;
    find_context->capacity = capacity;

    find_context->callback = callback;
    find_context->callback_queue = callback_queue;

    find_context->service_ref = NULL;

    dispatch_block_flags_t block_flags = 0;
    find_context->timeout_block = dispatch_block_create(block_flags, ^{
        complete_find_file_shares(find_context, kDNSServiceErr_NoError);
    });
    NSCAssert(find_context->timeout_block, @"Expected to create timeout_block");

    return find_context;
}


static struct url_context *alloc_url_context(
    struct file_share const *file_share,
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


static void browse_reply(
    DNSServiceRef service_ref,
    DNSServiceFlags flags,
    uint32_t interface_index,
    DNSServiceErrorType error_code,
    const char *service_name,
    const char *service_type,
    const char *domain,
    void *context
)
{
    struct find_context *find_context = context;
    if (kDNSServiceErr_NoError != error_code) {
        complete_find_file_shares(find_context, error_code);
        return;
    }

    if (kDNSServiceFlagsAdd & flags) {
        if (find_context->count < find_context->capacity) {
            int i = find_context->count;

            find_context->file_shares[i].interface_index = interface_index;
            strlcpy(
                find_context->file_shares[i].service_name,
                service_name,
                sizeof find_context->file_shares[i].service_name
            );
            strlcpy(
                find_context->file_shares[i].service_type,
                service_type,
                sizeof find_context->file_shares[i].service_type
            );
            strlcpy(
                find_context->file_shares[i].domain,
                domain,
                sizeof find_context->file_shares[i].domain
            );

            ++find_context->count;
        }
    } else {
        int i = matching_file_share(
            find_context->file_shares,
            find_context->count,
            interface_index,
            service_name,
            service_type,
            domain
        );
        if (i >= 0) {
            int count_after = find_context->count - i - 1;
            if (count_after) {
                struct file_share *destination = &find_context->file_shares[i];
                struct file_share *source = &find_context->file_shares[i + 1];
                size_t size = sizeof(struct file_share) * count_after;
                memmove(destination, source, size);
            }
            --find_context->count;
        }
    }
}


static void complete_find_file_shares(
    struct find_context *find_context, DNSServiceErrorType error_code
)
{
    find_file_shares_callback *callback = find_context->callback;
    struct file_share *file_shares = find_context->file_shares;
    int count = find_context->count;
    dispatch_async(find_context->callback_queue, ^{
        callback(file_shares, count, error_code);
    });
    free_find_context(find_context);
}


void find_file_shares(
    dispatch_queue_t serial_queue,
    struct file_share *file_shares,
    int capacity,
    find_file_shares_callback callback,
    dispatch_queue_t callback_queue,
    int timeout_secs
)
{
    dispatch_assert_queue(serial_queue);

    struct find_context *find_context =
        alloc_find_context(file_shares, capacity, callback, callback_queue);
    if (!find_context) {
        dispatch_async(callback_queue, ^{
            int count = 0;
            callback(file_shares, count, kDNSServiceErr_NoMemory);
        });
        return;
    }

    DNSServiceErrorType error_code;

    DNSServiceFlags flags = 0;
    char const *domain = NULL;
    error_code = DNSServiceBrowse(
        &find_context->service_ref,
        flags,
        kDNSServiceInterfaceIndexAny,
        "_mcmus._tcp",
        domain,
        browse_reply,
        find_context
    );
    if (kDNSServiceErr_NoError != error_code) {
        free_find_context(find_context);
        dispatch_async(callback_queue, ^{
            int count = 0;
            callback(file_shares, count, error_code);
        });
        return;
    }

    error_code =
        DNSServiceSetDispatchQueue(find_context->service_ref, serial_queue);
    if (kDNSServiceErr_NoError != error_code) {
        free_find_context(find_context);
        dispatch_async(callback_queue, ^{
            int count = 0;
            callback(file_shares, count, error_code);
        });
        return;
    }

    dispatch_time_t timeout_nanos = dispatch_time(
        DISPATCH_TIME_NOW, (int64_t)(timeout_secs * NSEC_PER_SEC)
    );
    dispatch_after(timeout_nanos, serial_queue, find_context->timeout_block);
}


static void free_find_context(struct find_context *find_context)
{
    find_context->callback_queue = nil;

    if (find_context->service_ref) {
        DNSServiceRefDeallocate(find_context->service_ref);
    }

    if (find_context->timeout_block) {
        dispatch_block_cancel(find_context->timeout_block);
    }
    find_context->timeout_block = nil;

    free(find_context);
}


static void free_url_context(struct url_context *url_context)
{
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
    struct file_share const *file_share,
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
        file_share->interface_index,
        file_share->service_name,
        file_share->service_type,
        file_share->domain,
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


static int matching_file_share(
    struct file_share *file_shares,
    int count,
    uint32_t interface_index,
    char const *service_name,
    char const *service_type,
    char const *domain
)
{
    for (int i = 0; i < count; ++i) {
        if (file_shares[i].interface_index == interface_index
            && 0 == strcmp(file_shares[i].service_name, service_name)
            && 0 == strcmp(file_shares[i].service_type, service_type)
            && 0 == strcmp(file_shares[i].domain, domain))
        {
            return i;
        }
    }
    return -1;
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
