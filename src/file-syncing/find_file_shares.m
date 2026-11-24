#import "find_file_shares.h"

#import "FileShare.h"


// alloc with `alloc_find_context()` and free with `free_find_context()`
struct find_context {
    NSMutableArray<FileShare *> *file_shares;
    find_file_shares_callback *callback;
    dispatch_queue_t callback_queue;
    DNSServiceRef service_ref;
    dispatch_block_t timeout_block;
};


static void complete_find_file_shares(
    struct find_context *find_context, DNSServiceErrorType error_code
);

static void free_find_context(struct find_context *find_context);

static int matching_file_share(
    NSArray<FileShare *> *fileShares,
    uint32_t interface_index,
    char const *service_name,
    char const *service_type,
    char const *domain
);


static struct find_context *alloc_find_context(
    find_file_shares_callback callback, dispatch_queue_t callback_queue
)
{
    struct find_context *find_context = calloc(1, sizeof(struct find_context));
    if (!find_context) return NULL;

    find_context->file_shares = [NSMutableArray new];

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
        FileShare *fileShare =
            [[FileShare alloc] initWithInterfaceIndex:interface_index
                                          serviceName:service_name
                                              regtype:service_type
                                          replyDomain:domain];
        [find_context->file_shares addObject:fileShare];
    } else {
        int i = matching_file_share(
            find_context->file_shares,
            interface_index,
            service_name,
            service_type,
            domain
        );
        if (i >= 0) {
            [find_context->file_shares removeObjectAtIndex:i];
        }
    }
}


static void complete_find_file_shares(
    struct find_context *find_context, DNSServiceErrorType error_code
)
{
    find_file_shares_callback *callback = find_context->callback;
    NSArray<FileShare *> *fileShares = [find_context->file_shares copy];
    dispatch_async(find_context->callback_queue, ^{
        callback(fileShares, error_code);
    });
    free_find_context(find_context);
}


void find_file_shares(
    dispatch_queue_t serial_queue,
    find_file_shares_callback callback,
    dispatch_queue_t callback_queue,
    int timeout_secs
)
{
    dispatch_assert_queue(serial_queue);

    struct find_context *find_context =
        alloc_find_context(callback, callback_queue);
    if (!find_context) {
        dispatch_async(callback_queue, ^{
            NSArray<FileShare *> *fileShares = @[];
            callback(fileShares, kDNSServiceErr_NoMemory);
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
            NSArray<FileShare *> *fileShares = @[];
            callback(fileShares, error_code);
        });
        return;
    }

    error_code =
        DNSServiceSetDispatchQueue(find_context->service_ref, serial_queue);
    if (kDNSServiceErr_NoError != error_code) {
        free_find_context(find_context);
        dispatch_async(callback_queue, ^{
            NSArray<FileShare *> *fileShares = @[];
            callback(fileShares, error_code);
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
    find_context->file_shares = nil;
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


static int matching_file_share(
    NSArray<FileShare *> *fileShares,
    uint32_t interface_index,
    char const *service_name,
    char const *service_type,
    char const *domain
)
{
    for (int i = 0; i < fileShares.count; ++i) {
        FileShare *fileShare = [fileShares objectAtIndex:i];
        if (fileShare.interfaceIndex == interface_index
            && 0 == strcmp(fileShare.serviceName.UTF8String, service_name)
            && 0 == strcmp(fileShare.serviceType.UTF8String, service_type)
            && 0 == strcmp(fileShare.domain.UTF8String, domain))
        {
            return i;
        }
    }
    return -1;
}
