#import "NetworkReal.h"

#import <arpa/inet.h>
#import <dns_sd.h>
#import <fcntl.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>


NSErrorDomain const NetworkAdvertisementErrorDomain =
    @"NetworkAdvertisementErrorDomain";


static NSError *posix_error(void)
{
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
}


static NSError *advertisement_error(DNSServiceErrorType code)
{
    return [NSError errorWithDomain:NetworkAdvertisementErrorDomain
                               code:code
                           userInfo:nil];
}


static BOOL make_nonblocking(int fd)
{
    int flags = fcntl(fd, F_GETFL);
    return flags != -1 && fcntl(fd, F_SETFL, flags | O_NONBLOCK) != -1;
}


// The socket does not retain `info`; the owner invalidates the socket when it
// closes or is deallocated, which stops the callbacks.
static CFSocketRef schedule_socket(
    int fd,
    CFOptionFlags callbackTypes,
    CFSocketCallBack callback,
    void *info,
    BOOL closeOnInvalidate
)
{
    CFSocketContext context = {.info = info};
    CFSocketRef socket =
        CFSocketCreateWithNative(NULL, fd, callbackTypes, callback, &context);
    if (!socket) return NULL;

    if (!closeOnInvalidate) {
        CFOptionFlags flags = CFSocketGetSocketFlags(socket);
        CFSocketSetSocketFlags(socket, flags & ~kCFSocketCloseOnInvalidate);
    }
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);
    return socket;
}


static void unschedule_socket(CFSocketRef socket)
{
    CFSocketInvalidate(socket);
    CFRelease(socket);
}


static NSString *client_address(int fd)
{
    struct sockaddr_in6 address;
    socklen_t length = sizeof address;
    if (getpeername(fd, (struct sockaddr *)&address, &length) == -1) return @"";

    char text[INET6_ADDRSTRLEN] = "";
    if (IN6_IS_ADDR_V4MAPPED(&address.sin6_addr)) {
        const void *ipv4Address = &address.sin6_addr.s6_addr[12];
        inet_ntop(AF_INET, ipv4Address, text, sizeof text);
    } else {
        inet_ntop(AF_INET6, &address.sin6_addr, text, sizeof text);
    }
    return @(text);
}


@interface PendingSend : NSObject

@property (nonatomic, readonly) NSData *data;
@property (nonatomic) NSUInteger offset;
@property (nonatomic, readonly, nullable) void (^completion)(void);

@end


@implementation PendingSend


- (instancetype)initWithData:(NSData *)data
                  completion:(nullable void (^)(void))completion;
{
    self = [super init];
    if (!self) return nil;

    _data = [data copy];
    _completion = [completion copy];

    return self;
}


@end


@interface NetworkConnectionReal : NSObject <NetworkConnection>

- (void)readAvailableData;
- (void)sendPendingData;

@end


static void connection_callback(
    CFSocketRef socket,
    CFSocketCallBackType type,
    CFDataRef address,
    const void *data,
    void *info
)
{
    NetworkConnectionReal *connection = (__bridge NetworkConnectionReal *)info;
    if (type == kCFSocketReadCallBack) [connection readAvailableData];
    if (type == kCFSocketWriteCallBack) [connection sendPendingData];
}


@implementation NetworkConnectionReal {
    int _fd;
    CFSocketRef _socket;
    NSMutableArray<PendingSend *> *_pendingSends;
}

@synthesize clientAddress = _clientAddress;
@synthesize onData = _onData;
@synthesize onBytesSent = _onBytesSent;
@synthesize onClosed = _onClosed;


- (nullable instancetype)initWithAcceptedSocket:(int)fd;
{
    self = [super init];
    if (!self) return nil;

    _fd = fd;
    _clientAddress = client_address(fd);
    _pendingSends = [NSMutableArray new];
    [self preventSIGPIPE];
    if (make_nonblocking(fd)) {
        _socket = schedule_socket(
            fd, kCFSocketReadCallBack | kCFSocketWriteCallBack,
            connection_callback, (__bridge void *)self, YES
        );
    }
    if (!_socket) {
        close(fd);
        return nil;
    }

    return self;
}


- (void)dealloc;
{
    [self close];
}


// Without this, sending to a client that has gone away raises SIGPIPE and
// terminates the app instead of failing with EPIPE.
- (void)preventSIGPIPE;
{
    int on = 1;
    setsockopt(_fd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof on);
}


- (void)send:(NSData *)data completion:(nullable void (^)(void))completion;
{
    if (!_socket) return;
    [_pendingSends addObject:[[PendingSend alloc] initWithData:data
                                                    completion:completion]];
    [self sendPendingData];
}


- (void)close;
{
    if (!_socket) return;
    unschedule_socket(_socket);
    _socket = NULL;
    [_pendingSends removeAllObjects];
    _onData = nil;
    _onBytesSent = nil;
    _onClosed = nil;
}


// Each block is held in a local while it runs because the block may close
// the connection, which releases the instance variable.
- (void)readAvailableData;
{
    uint8_t buffer[16 * 1024];
    while (_socket) {
        ssize_t count = recv(_fd, buffer, sizeof buffer, 0);
        if (count > 0) {
            void (^onData)(NSData *) = _onData;
            if (onData) onData([NSData dataWithBytes:buffer length:count]);
        } else if (count == 0) {
            [self closeAndReport];
        } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return;
        } else if (errno != EINTR) {
            [self closeAndReport];
        }
    }
}


- (void)sendPendingData;
{
    while (_socket && _pendingSends.count) {
        PendingSend *pending = _pendingSends.firstObject;
        const uint8_t *bytes = pending.data.bytes;
        size_t remaining = pending.data.length - pending.offset;
        ssize_t count = send(_fd, bytes + pending.offset, remaining, 0);
        if (count >= 0) {
            pending.offset += count;
            BOOL isFinished = pending.offset == pending.data.length;
            if (isFinished) [_pendingSends removeObjectAtIndex:0];
            void (^onBytesSent)(NSUInteger) = _onBytesSent;
            if (onBytesSent && count) onBytesSent(count);
            if (isFinished && pending.completion) pending.completion();
        } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
            CFSocketEnableCallBacks(_socket, kCFSocketWriteCallBack);
            return;
        } else if (errno != EINTR) {
            [self closeAndReport];
        }
    }
}


- (void)closeAndReport;
{
    void (^onClosed)(void) = _onClosed;
    [self close];
    if (onClosed) onClosed();
}


@end


@interface NetworkListenerReal : NSObject <NetworkListener>

- (void)accept:(int)fd;

@end


static void listener_callback(
    CFSocketRef socket,
    CFSocketCallBackType type,
    CFDataRef address,
    const void *data,
    void *info
)
{
    NetworkListenerReal *listener = (__bridge NetworkListenerReal *)info;
    [listener accept:*(const CFSocketNativeHandle *)data];
}


@implementation NetworkListenerReal {
    CFSocketRef _socket;
}

@synthesize port = _port;
@synthesize onConnection = _onConnection;


- (nullable instancetype)initAndReturnError:(NSError **)error;
{
    self = [super init];
    if (!self) return nil;

    int fd = socket(AF_INET6, SOCK_STREAM, 0);
    if (fd == -1) {
        if (error) *error = posix_error();
        return nil;
    }
    if (![self listenOnAvailablePort:fd]) {
        if (error) *error = posix_error();
        close(fd);
        return nil;
    }
    _socket = schedule_socket(
        fd, kCFSocketAcceptCallBack, listener_callback, (__bridge void *)self,
        YES
    );
    if (!_socket) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:ENOTSOCK
                                     userInfo:nil];
        close(fd);
        return nil;
    }

    return self;
}


- (void)dealloc;
{
    [self close];
}


// An IPv6 socket that is not IPv6-only also accepts IPv4 clients, so one
// socket serves both protocols on the same port.
- (BOOL)listenOnAvailablePort:(int)fd;
{
    int off = 0;
    struct sockaddr_in6 address = {
        .sin6_len = sizeof address,
        .sin6_family = AF_INET6,
        .sin6_addr = in6addr_any,
        .sin6_port = 0,
    };
    socklen_t length = sizeof address;
    BOOL isListening =
        setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &off, sizeof off) == 0
        && bind(fd, (struct sockaddr *)&address, length) == 0
        && listen(fd, SOMAXCONN) == 0
        && getsockname(fd, (struct sockaddr *)&address, &length) == 0
        && make_nonblocking(fd);
    if (isListening) _port = ntohs(address.sin6_port);
    return isListening;
}


- (void)accept:(int)fd;
{
    NetworkConnectionReal *connection =
        [[NetworkConnectionReal alloc] initWithAcceptedSocket:fd];
    void (^onConnection)(id<NetworkConnection>) = _onConnection;
    if (connection && onConnection) onConnection(connection);
}


- (void)close;
{
    if (!_socket) return;
    unschedule_socket(_socket);
    _socket = NULL;
    _onConnection = nil;
}


@end


@interface NetworkAdvertisementReal : NSObject <NetworkAdvertisement>

- (void)processResult;
- (void)failWithCode:(DNSServiceErrorType)code;

@end


static void advertisement_socket_callback(
    CFSocketRef socket,
    CFSocketCallBackType type,
    CFDataRef address,
    const void *data,
    void *info
)
{
    NetworkAdvertisementReal *advertisement =
        (__bridge NetworkAdvertisementReal *)info;
    [advertisement processResult];
}


static void advertisement_registered(
    DNSServiceRef service,
    DNSServiceFlags flags,
    DNSServiceErrorType code,
    const char *name,
    const char *type,
    const char *domain,
    void *context
)
{
    NetworkAdvertisementReal *advertisement =
        (__bridge NetworkAdvertisementReal *)context;
    if (code != kDNSServiceErr_NoError) [advertisement failWithCode:code];
}


@implementation NetworkAdvertisementReal {
    DNSServiceRef _service;
    CFSocketRef _socket;
}

@synthesize onFailed = _onFailed;


- (nullable instancetype)initWithType:(NSString *)type
                                 port:(uint16_t)port
                                error:(NSError **)error;
{
    self = [super init];
    if (!self) return nil;

    DNSServiceErrorType code = DNSServiceRegister(
        &_service, 0, kDNSServiceInterfaceIndexAny, NULL, type.UTF8String, NULL,
        NULL, htons(port), 0, NULL, advertisement_registered,
        (__bridge void *)self
    );
    if (code != kDNSServiceErr_NoError) {
        if (error) *error = advertisement_error(code);
        return nil;
    }
    _socket = [self scheduleResults];
    if (!_socket) {
        if (error) *error = advertisement_error(kDNSServiceErr_Unknown);
        [self close];
        return nil;
    }

    return self;
}


- (void)dealloc;
{
    [self close];
}


// Registration results arrive on a socket owned by the service, which must
// be read with DNSServiceProcessResult() and closed only by deallocating the
// service.
- (nullable CFSocketRef)scheduleResults;
{
    return schedule_socket(
        DNSServiceRefSockFD(_service), kCFSocketReadCallBack,
        advertisement_socket_callback, (__bridge void *)self, NO
    );
}


- (void)processResult;
{
    DNSServiceErrorType code = DNSServiceProcessResult(_service);
    if (code != kDNSServiceErr_NoError) [self failWithCode:code];
}


- (void)failWithCode:(DNSServiceErrorType)code;
{
    void (^onFailed)(NSError *) = _onFailed;
    [self close];
    if (onFailed) onFailed(advertisement_error(code));
}


- (void)close;
{
    if (_socket) {
        unschedule_socket(_socket);
        _socket = NULL;
    }
    if (_service) {
        DNSServiceRefDeallocate(_service);
        _service = NULL;
    }
    _onFailed = nil;
}


@end


@implementation NetworkReal


- (nullable id<NetworkListener>)listenAndReturnError:(NSError **)error;
{
    return [[NetworkListenerReal alloc] initAndReturnError:error];
}


- (nullable id<NetworkAdvertisement>)advertiseServiceOfType:(NSString *)type
                                                       port:(uint16_t)port
                                                      error:(NSError **)error;
{
    return [[NetworkAdvertisementReal alloc] initWithType:type
                                                     port:port
                                                    error:error];
}


@end
