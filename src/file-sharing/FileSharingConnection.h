#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@class FileSharingConnection;
@class HTTPRequest;
@protocol Clock;
@protocol NetworkConnection;


NS_ASSUME_NONNULL_BEGIN


// Returns the next part of a response body, or nil when it cannot be
// produced.
typedef NSData *_Nullable (^ResponseBodySource)(void);


@protocol FileSharingConnectionDelegate <NSObject>

- (void)connectionDidBeginRequest:(FileSharingConnection *)connection;
// The request is nil when it could not be parsed. The delegate must answer
// with `respond:closing:` or `respondWithHeader:bodyLength:body:closing:`.
- (void)connection:(FileSharingConnection *)connection
    didReceiveRequest:(nullable HTTPRequest *)request;
- (void)connectionDidEndRequest:(FileSharingConnection *)connection;
- (void)connectionDidClose:(FileSharingConnection *)connection;

@end


// One client connection to the file sharing server: reads requests one at a
// time, sends the delegate's responses and closes itself when the client is
// too slow.
@interface FileSharingConnection : NSObject

@property (nonatomic, readonly) NSString *clientAddress;
// True when the client already had its full allowance of connections open
// when this one was accepted.
@property (nonatomic, readonly) BOOL isOverClientLimit;
// True from the first bytes of a request until the last bytes of its
// response are sent or the connection closes.
@property (nonatomic, readonly) BOOL hasActiveRequest;
@property (nonatomic, weak, nullable) id<FileSharingConnectionDelegate>
    delegate;

- (instancetype)initWithConnection:(id<NetworkConnection>)connection
                             clock:(id<Clock>)clock
                 isOverClientLimit:(BOOL)isOverClientLimit
                          delegate:(id<FileSharingConnectionDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)respond:(NSData *)response closing:(BOOL)closesConnection;
// Sends the header, then asks the body source for one part at a time, each
// only once the part before it has been sent, until `bodyLength` bytes are
// sent. The connection closes if the body source returns nil, no bytes or
// more bytes than remain.
- (void)respondWithHeader:(NSData *)header
               bodyLength:(unsigned long long)bodyLength
                     body:(nullable ResponseBodySource)body
                  closing:(BOOL)closesConnection;
- (void)close;

@end


NS_ASSUME_NONNULL_END


#endif
