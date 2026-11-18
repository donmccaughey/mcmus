#import "FileSharingServer.h"

#if TARGET_OS_OSX


#import <os/log.h>

#import "Clock.h"
#import "FileSharingConnection.h"
#import "HTTPRequestParser.h"
#import "HTTPResponse.h"
#import "Network.h"


static NSString *const serviceType = @"_mcmus._tcp";
static const NSUInteger maxConnections = 16;
static const NSUInteger maxConnectionsPerClient = 6;
static const NSTimeInterval clientTimeout = 5;
static const NSUInteger maxDeviceNameLength = 64;


static os_log_t server_log(void)
{
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("cc.donm.mcmus", "server"); });
    return log;
}


// The User-Agent header is untrusted text that ends up in the user interface.
static NSString *_Nullable device_name(NSString *_Nullable userAgent)
{
    NSArray<NSString *> *parts = [userAgent
        componentsSeparatedByCharactersInSet:NSCharacterSet
                                                 .controlCharacterSet];
    NSString *name = [[parts componentsJoinedByString:@""]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (name.length > maxDeviceNameLength) {
        NSRange kept = [name
            rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,
                                                          maxDeviceNameLength)];
        name = [name substringWithRange:kept];
    }
    return name.length ? name : nil;
}


@interface FileSharingServer () <FileSharingConnectionDelegate>
@end


@implementation FileSharingServer {
    id<Network> _network;
    id<Clock> _clock;
    NSData *_manifest;
    id<NetworkListener> _Nullable _listener;
    id<NetworkAdvertisement> _Nullable _advertisement;
    NSMutableArray<FileSharingConnection *> *_connections;
    NSString *_Nullable _clientAddress;
    NSString *_Nullable _deviceName;
    id<ClockTimer> _Nullable _clientTimeoutTimer;
}


- (instancetype)initWithNetwork:(id<Network>)network
                          clock:(id<Clock>)clock
                       manifest:(NSData *)manifest;
{
    self = [super init];
    if (!self) return nil;

    _network = network;
    _clock = clock;
    _manifest = [manifest copy];
    _connections = [NSMutableArray new];

    return self;
}


- (uint16_t)port;
{
    return _listener.port;
}


- (BOOL)startAndReturnError:(NSError **)error;
{
    _listener = [_network listenAndReturnError:error];
    if (!_listener) return NO;

    _advertisement = [_network advertiseServiceOfType:serviceType
                                                 port:_listener.port
                                                error:error];
    if (!_advertisement) {
        [_listener close];
        _listener = nil;
        return NO;
    }

    __weak typeof(self) weakSelf = self;
    _listener.onConnection =
        ^(id<NetworkConnection> connection) { [weakSelf accept:connection]; };
    _advertisement.onFailed = ^(NSError *advertisementError) {
        os_log_error(
            server_log(), "Advertising failed: %{public}@", advertisementError);
    };
    os_log(server_log(), "Listening on port %d", _listener.port);
    [self enterWaitingForClient];
    return YES;
}


- (void)stop;
{
    [_clientTimeoutTimer cancel];
    _clientTimeoutTimer = nil;
    [_advertisement close];
    _advertisement = nil;
    [_listener close];
    _listener = nil;

    NSArray<FileSharingConnection *> *connections = [_connections copy];
    [_connections removeAllObjects];
    for (FileSharingConnection *connection in connections) {
        connection.delegate = nil;
        [connection close];
    }
    _clientAddress = nil;
    _deviceName = nil;
    _state = FileSharingServerStateWaitingForClient;
}


- (void)accept:(id<NetworkConnection>)connection;
{
    if (_connections.count >= maxConnections) {
        [connection close];
        return;
    }
    NSUInteger clientConnectionCount =
        [self countOfConnectionsFrom:connection.clientAddress];
    BOOL isOverClientLimit = clientConnectionCount >= maxConnectionsPerClient;
    [_connections addObject:[[FileSharingConnection alloc]
                                initWithConnection:connection
                                             clock:_clock
                                 isOverClientLimit:isOverClientLimit
                                          delegate:self]];
}


- (NSUInteger)countOfConnectionsFrom:(NSString *)clientAddress;
{
    NSUInteger count = 0;
    for (FileSharingConnection *connection in _connections) {
        if (connection.isOverClientLimit) continue;
        if ([connection.clientAddress isEqual:clientAddress]) ++count;
    }
    return count;
}


#pragma mark - States


- (void)enterWaitingForClient;
{
    _clientAddress = nil;
    _deviceName = nil;
    _state = FileSharingServerStateWaitingForClient;
    if (_onWaitingForClient) _onWaitingForClient();
}


- (void)enterClientConnected;
{
    _state = FileSharingServerStateClientConnected;
    if (_onClientConnected && _deviceName) _onClientConnected(_deviceName);
}


- (void)lingerIfClientHasNoActiveRequests;
{
    if (FileSharingServerStateClientConnected != _state) return;
    if ([self activeRequestCount]) return;

    _state = FileSharingServerStateClientLingering;
    __weak typeof(self) weakSelf = self;
    _clientTimeoutTimer = [_clock after:clientTimeout
                                    run:^{ [weakSelf clientDidTimeOut]; }];
}


- (void)stopLingering;
{
    [_clientTimeoutTimer cancel];
    _clientTimeoutTimer = nil;
    [self enterClientConnected];
}


// The client's idle connections are closed so that they cannot outlast its
// turn and count against the next client.
- (void)clientDidTimeOut;
{
    _clientTimeoutTimer = nil;
    NSArray<FileSharingConnection *> *clientConnections =
        [self connectionsFromClient];
    [self enterWaitingForClient];
    for (FileSharingConnection *connection in clientConnections) {
        [connection close];
    }
}


- (NSArray<FileSharingConnection *> *)connectionsFromClient;
{
    NSString *clientAddress = _clientAddress;
    NSIndexSet *indexes = [_connections indexesOfObjectsPassingTest:^BOOL(
        FileSharingConnection *connection, NSUInteger index, BOOL *stop) {
        return [connection.clientAddress isEqual:clientAddress];
    }];
    return [_connections objectsAtIndexes:indexes];
}


- (BOOL)isServingClientOn:(FileSharingConnection *)connection;
{
    return !connection.isOverClientLimit &&
        [connection.clientAddress isEqual:_clientAddress];
}


- (NSUInteger)activeRequestCount;
{
    NSUInteger count = 0;
    for (FileSharingConnection *connection in _connections) {
        if (![self isServingClientOn:connection]) continue;
        if (connection.hasActiveRequest) ++count;
    }
    return count;
}


#pragma mark - Requests


- (nullable NSData *)rejectionOf:(nullable HTTPRequest *)request
                              on:(FileSharingConnection *)connection;
{
    if (connection.isOverClientLimit) {
        return makeHTTPTextResponse(
            HTTPStatusTooManyRequests, @"Too many connections", YES);
    }
    if (!request) {
        return makeHTTPTextResponse(
            HTTPStatusBadRequest, @"Invalid request", YES);
    }
    BOOL isWaiting = FileSharingServerStateWaitingForClient == _state;
    if (!isWaiting && ![connection.clientAddress isEqual:_clientAddress]) {
        return makeHTTPTextResponse(
            HTTPStatusServiceUnavailable, @"Max clients connected", YES);
    }
    if (!device_name(request.userAgent)) {
        return makeHTTPTextResponse(
            HTTPStatusBadRequest, @"Missing User-Agent header", YES);
    }
    return nil;
}


- (NSData *)responseTo:(HTTPRequest *)request;
{
    BOOL closes = request.closesConnection;
    if (![request.path isEqual:@"/manifest"]) {
        return makeHTTPTextResponse(HTTPStatusNotFound, @"Not found", closes);
    }
    if (![request.method isEqual:@"GET"]) {
        return makeHTTPTextResponse(
            HTTPStatusMethodNotAllowed, @"Method not allowed", closes);
    }
    return makeHTTPResponse(
        HTTPStatusOK, @"text/csv;charset=UTF-8", _manifest, closes);
}


#pragma mark - FileSharingConnectionDelegate


- (void)connectionDidBeginRequest:(FileSharingConnection *)connection;
{
    BOOL isLingering = FileSharingServerStateClientLingering == _state;
    if (isLingering && [self isServingClientOn:connection]) {
        [self stopLingering];
    }
}


- (void)connection:(FileSharingConnection *)connection
    didReceiveRequest:(nullable HTTPRequest *)request;
{
    NSData *rejection = [self rejectionOf:request on:connection];
    if (rejection) {
        [connection respond:rejection closing:YES];
        return;
    }

    if (FileSharingServerStateWaitingForClient == _state) {
        _clientAddress = connection.clientAddress;
        _deviceName = device_name(request.userAgent);
        [self enterClientConnected];
    }
    [connection respond:[self responseTo:request]
                closing:request.closesConnection];
}


- (void)connectionDidEndRequest:(FileSharingConnection *)connection;
{
    [self lingerIfClientHasNoActiveRequests];
}


- (void)connectionDidClose:(FileSharingConnection *)connection;
{
    [_connections removeObjectIdenticalTo:connection];
    [self lingerIfClientHasNoActiveRequests];
}


@end


#endif
