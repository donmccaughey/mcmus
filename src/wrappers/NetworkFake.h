#import <Foundation/Foundation.h>

#import "Network.h"

NS_ASSUME_NONNULL_BEGIN

@interface NetworkConnectionFake : NSObject <NetworkConnection>

@property (nonatomic, readonly) NSData *sentData;
@property (nonatomic, readonly) NSString *sentText;
@property (nonatomic, readonly) BOOL isClosed;
// While set, sent data is held back as if the client had stopped reading;
// `finishSending` delivers it.
@property (nonatomic) BOOL isStalled;

- (void)receive:(NSString *)text;
- (void)finishSending;
- (void)closeByClient;

@end

@interface NetworkListenerFake : NSObject <NetworkListener>

@property (nonatomic, readonly) BOOL isClosed;

@end

@interface NetworkAdvertisementFake : NSObject <NetworkAdvertisement>

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) BOOL isClosed;

- (void)fail:(NSError *)error;

@end

@interface NetworkFake : NSObject <Network>

@property (nonatomic) uint16_t port;
@property (nonatomic, nullable) NSError *listenError;
@property (nonatomic, nullable) NSError *advertiseError;
@property (nonatomic, readonly, nullable) NetworkListenerFake *listener;
@property (nonatomic, readonly, nullable)
    NetworkAdvertisementFake *advertisement;

// Opens a connection to the listener as a client with the given IP address.
- (NetworkConnectionFake *)connectFrom:(NSString *)clientAddress;

@end

NS_ASSUME_NONNULL_END
