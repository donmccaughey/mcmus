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


NS_ASSUME_NONNULL_END


#endif
