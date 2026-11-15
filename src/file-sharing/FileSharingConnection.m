#import "FileSharingConnection.h"

#if TARGET_OS_OSX


#import "Clock.h"
#import "HTTPRequestParser.h"
#import "Network.h"


// The limit on the idle time, the request read time and the time a response
// may go without progress.
static const NSTimeInterval timeout = 10;

static const NSUInteger maxLengthReceivedWhileResponding = 64 * 1024;


@implementation FileSharingConnection {
    id<NetworkConnection> _connection;
    id<Clock> _clock;
    id<ClockTimer> _Nullable _timeoutTimer;
    HTTPRequestParser *_parser;
    NSMutableData *_receivedWhileResponding;
    BOOL _isResponding;
    BOOL _isClosed;
}


- (instancetype)initWithConnection:(id<NetworkConnection>)connection
                             clock:(id<Clock>)clock
                 isOverClientLimit:(BOOL)isOverClientLimit
                          delegate:(id<FileSharingConnectionDelegate>)delegate;
{
    self = [super init];
    if (!self) return nil;

    _connection = connection;
    _clock = clock;
    _isOverClientLimit = isOverClientLimit;
    _delegate = delegate;
    _parser = [HTTPRequestParser new];
    _receivedWhileResponding = [NSMutableData new];

    __weak typeof(self) weakSelf = self;
    connection.onData = ^(NSData *data) { [weakSelf didReceive:data]; };
    connection.onBytesSent = ^(NSUInteger count) { [weakSelf restartTimeout]; };
    connection.onClosed = ^{ [weakSelf close]; };
    [self restartTimeout];

    return self;
}


- (NSString *)clientAddress;
{
    return _connection.clientAddress;
}


- (void)restartTimeout;
{
    [_timeoutTimer cancel];
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [_clock after:timeout run:^{ [weakSelf close]; }];
}


- (void)didReceive:(NSData *)data;
{
    if (!_isResponding) {
        [self parse:data];
        return;
    }
    [_receivedWhileResponding appendData:data];
    if (_receivedWhileResponding.length > maxLengthReceivedWhileResponding) {
        [self close];
    }
}


// The timeout is restarted only at the first bytes of a request, so that it
// limits the time taken to read the whole request.
- (void)parse:(NSData *)data;
{
    if (!data.length) return;
    if (!_hasActiveRequest) {
        _hasActiveRequest = YES;
        [self restartTimeout];
        [_delegate connectionDidBeginRequest:self];
    }

    [_parser append:data];
    if (HTTPRequestParserStateIncomplete == _parser.state) return;

    _isResponding = YES;
    [_delegate connection:self didReceiveRequest:_parser.request];
}


- (void)respond:(NSData *)response closing:(BOOL)closesConnection;
{
    [self restartTimeout];
    __weak typeof(self) weakSelf = self;
    [_connection send:response
           completion:^{
               if (closesConnection) {
                   [weakSelf close];
               } else {
                   [weakSelf readNextRequest];
               }
           }];
}


// When the client has already sent the start of its next request, that
// request is active from the moment this one ends, so the delegate is not
// told of a gap between them.
- (void)readNextRequest;
{
    NSMutableData *received = [_parser.excessData mutableCopy];
    [received appendData:_receivedWhileResponding];
    _receivedWhileResponding.length = 0;
    _parser = [HTTPRequestParser new];
    _isResponding = NO;
    [self restartTimeout];

    if (received.length) {
        [self parse:received];
    } else {
        _hasActiveRequest = NO;
        [_delegate connectionDidEndRequest:self];
    }
}


- (void)close;
{
    if (_isClosed) return;
    _isClosed = YES;
    _hasActiveRequest = NO;
    [_timeoutTimer cancel];
    _timeoutTimer = nil;
    [_connection close];
    [_delegate connectionDidClose:self];
}


@end


#endif
