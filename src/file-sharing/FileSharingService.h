#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


// The messages the app sends to the file sharing side. Shaped like an XPC
// interface so that the sharing side can move to a separate process later:
// void methods, one reply block each, and the reply may arrive on any thread.
@protocol FileSharingService <NSObject>

- (void)startSharingMusicDirectory:(NSURL *)musicDir
                             reply:(void (^)(NSError *_Nullable error))reply;
- (void)stopSharingWithReply:(void (^)(NSError *_Nullable error))reply;

@end


// The messages the file sharing side sends back to the app outside of a
// reply, the counterpart of an XPC connection's exported object. They may
// arrive on any thread.
@protocol FileSharingClient <NSObject>

- (void)didLoadMetadataForTracks:(NSUInteger)tracksLoaded
                         ofTotal:(NSUInteger)totalTracks;

@end


NS_ASSUME_NONNULL_END


#endif
