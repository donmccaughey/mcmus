#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Every block in these protocols runs on the run loop of the thread that
// created the object, and no block runs after the object is closed.

@protocol NetworkConnection <NSObject>

// The client's IP address in presentation form. An IPv4 client reaching a
// dual-stack listener is reported by its IPv4 address.
@property (nonatomic, readonly, copy) NSString *clientAddress;
@property (nonatomic, copy, nullable) void (^onData)(NSData *data);
@property (nonatomic, copy, nullable) void (^onBytesSent)(NSUInteger count);
// Runs when the client closes the connection or the connection fails; the
// connection is already closed when it runs.
@property (nonatomic, copy, nullable) void (^onClosed)(void);

// The completion runs once all of the data has been handed to the system,
// which may be before this method returns.
- (void)send:(NSData *)data completion:(nullable void (^)(void))completion;
- (void)close;

@end

@protocol NetworkListener <NSObject>

@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, copy, nullable) void (^onConnection)
    (id<NetworkConnection> connection);

- (void)close;

@end

@protocol NetworkAdvertisement <NSObject>

// Runs when the service cannot be registered or stops being advertised.
@property (nonatomic, copy, nullable) void (^onFailed)(NSError *error);

- (void)close;

@end

@protocol Network <NSObject>

// Listens for TCP connections over IPv4 and IPv6 on a port chosen by the
// system.
- (nullable id<NetworkListener>)listenAndReturnError:(NSError **)error;
// Advertises a Bonjour service such as `_mcmus._tcp` under the computer's
// name.
- (nullable id<NetworkAdvertisement>)advertiseServiceOfType:(NSString *)type
                                                       port:(uint16_t)port
                                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
