#import "NetworkFake.h"


@implementation NetworkConnectionFake {
    NSMutableData *_sentData;
    NSMutableArray<NSData *> *_heldData;
    NSMutableArray<void (^)(void)> *_heldCompletions;
}

@synthesize clientAddress = _clientAddress;
@synthesize onData = _onData;
@synthesize onBytesSent = _onBytesSent;
@synthesize onClosed = _onClosed;


- (instancetype)initWithClientAddress:(NSString *)clientAddress;
{
    self = [super init];
    if (!self) return nil;

    _clientAddress = [clientAddress copy];
    _sentData = [NSMutableData new];
    _heldData = [NSMutableArray new];
    _heldCompletions = [NSMutableArray new];

    return self;
}


- (NSData *)sentData;
{
    return [_sentData copy];
}


- (NSString *)sentText;
{
    return [[NSString alloc] initWithData:_sentData
                                 encoding:NSUTF8StringEncoding];
}


- (void)send:(NSData *)data completion:(nullable void (^)(void))completion;
{
    if (_isClosed) return;
    if (_isStalled) {
        [_heldData addObject:[data copy]];
        void (^noCompletion)(void) = ^{};
        [_heldCompletions addObject:[(completion ?: noCompletion) copy]];
        return;
    }
    [self deliver:data completion:completion];
}


- (void)deliver:(NSData *)data completion:(nullable void (^)(void))completion;
{
    [_sentData appendData:data];
    void (^onBytesSent)(NSUInteger) = _onBytesSent;
    if (onBytesSent && data.length) onBytesSent(data.length);
    if (completion) completion();
}


- (void)finishSending;
{
    _isStalled = NO;
    NSArray<NSData *> *heldData = [_heldData copy];
    NSArray<void (^)(void)> *heldCompletions = [_heldCompletions copy];
    [_heldData removeAllObjects];
    [_heldCompletions removeAllObjects];
    for (NSUInteger i = 0; i < heldData.count && !_isClosed; ++i) {
        [self deliver:heldData[i] completion:heldCompletions[i]];
    }
}


- (void)close;
{
    _isClosed = YES;
    [_heldData removeAllObjects];
    [_heldCompletions removeAllObjects];
    _onData = nil;
    _onBytesSent = nil;
    _onClosed = nil;
}


- (void)receive:(NSString *)text;
{
    void (^onData)(NSData *) = _onData;
    if (onData) onData([text dataUsingEncoding:NSUTF8StringEncoding]);
}


- (void)closeByClient;
{
    if (_isClosed) return;
    void (^onClosed)(void) = _onClosed;
    [self close];
    if (onClosed) onClosed();
}


@end


@implementation NetworkListenerFake

@synthesize port = _port;
@synthesize onConnection = _onConnection;


- (instancetype)initWithPort:(uint16_t)port;
{
    self = [super init];
    if (!self) return nil;

    _port = port;

    return self;
}


- (void)close;
{
    _isClosed = YES;
    _onConnection = nil;
}


@end


@implementation NetworkAdvertisementFake

@synthesize onRegistered = _onRegistered;
@synthesize onFailed = _onFailed;


- (instancetype)initWithType:(NSString *)type port:(uint16_t)port;
{
    self = [super init];
    if (!self) return nil;

    _type = [type copy];
    _port = port;

    return self;
}


- (void)registerWithName:(NSString *)name;
{
    void (^onRegistered)(NSString *) = _onRegistered;
    if (onRegistered) onRegistered(name);
}


- (void)fail:(NSError *)error;
{
    void (^onFailed)(NSError *) = _onFailed;
    [self close];
    if (onFailed) onFailed(error);
}


- (void)close;
{
    _isClosed = YES;
    _onRegistered = nil;
    _onFailed = nil;
}


@end


@implementation NetworkFake


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _port = 49152;

    return self;
}


- (nullable id<NetworkListener>)listenAndReturnError:(NSError **)error;
{
    if (_listenError) {
        if (error) *error = _listenError;
        return nil;
    }
    _listener = [[NetworkListenerFake alloc] initWithPort:_port];
    return _listener;
}


- (nullable id<NetworkAdvertisement>)advertiseServiceOfType:(NSString *)type
                                                       port:(uint16_t)port
                                                      error:(NSError **)error;
{
    if (_advertiseError) {
        if (error) *error = _advertiseError;
        return nil;
    }
    _advertisement = [[NetworkAdvertisementFake alloc] initWithType:type
                                                               port:port];
    return _advertisement;
}


- (NetworkConnectionFake *)connectFrom:(NSString *)clientAddress;
{
    NetworkConnectionFake *connection =
        [[NetworkConnectionFake alloc] initWithClientAddress:clientAddress];
    void (^onConnection)(id<NetworkConnection>) = _listener.onConnection;
    if (onConnection) {
        onConnection(connection);
    } else {
        [connection close];
    }
    return connection;
}


@end
