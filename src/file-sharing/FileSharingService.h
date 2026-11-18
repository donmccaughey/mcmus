#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


// The messages the app sends to the file sharing side. Shaped like an XPC
// interface so that the sharing side can move to a separate process later:
// void methods, one reply block each, and the reply may arrive on any thread.
@protocol FileSharingService <NSObject>

// The reply carries the port the server is listening on, or zero with an
// error when sharing did not start.
- (void)startSharingMusicDirectory:(NSURL *)musicDir
                  workingDirectory:(NSURL *)workingDir
                             reply:(void (^)(uint16_t port,
                                       NSError *_Nullable error))reply;
- (void)stopSharingWithReply:(void (^)(NSError *_Nullable error))reply;

@end


// The messages the file sharing side sends back to the app outside of a
// reply, the counterpart of an XPC connection's exported object. They may
// arrive on any thread.
@protocol FileSharingClient <NSObject>

- (void)didLoadMetadataForTracks:(NSUInteger)tracksLoaded
                         ofTotal:(NSUInteger)totalTracks;
- (void)serverIsWaitingForClient;
- (void)serverDidConnectClient:(NSString *)deviceName;

@end


NS_ASSUME_NONNULL_END


#endif
