#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@class FileSharingConnection;
@class HTTPRequest;
@protocol Clock;
@protocol NetworkConnection;


NS_ASSUME_NONNULL_BEGIN


@protocol FileSharingConnectionDelegate <NSObject>

- (void)connectionDidBeginRequest:(FileSharingConnection *)connection;
// The request is nil when it could not be parsed. The delegate must answer
// with `respond:closing:`.
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
- (void)close;

@end


NS_ASSUME_NONNULL_END


#endif
