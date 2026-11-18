#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@protocol Clock;
@protocol Network;


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, FileSharingServerState) {
    FileSharingServerStateWaitingForClient,
    FileSharingServerStateClientConnected,
    FileSharingServerStateClientLingering,
};


// Runs on the run loop of the thread that starts it, which is also where its
// blocks run.
@interface FileSharingServer : NSObject

@property (nonatomic, readonly) FileSharingServerState state;
// Zero unless the server is started.
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, copy, nullable) void (^onWaitingForClient)(void);
@property (nonatomic, copy, nullable) void (^onClientConnected)
    (NSString *deviceName);

- (instancetype)initWithNetwork:(id<Network>)network
                          clock:(id<Clock>)clock
                       manifest:(NSData *)manifest NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)startAndReturnError:(NSError **)error;
- (void)stop;

@end


NS_ASSUME_NONNULL_END


#endif
