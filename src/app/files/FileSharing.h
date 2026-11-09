#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, FileSharingState) {
    FileSharingStateOff,
    FileSharingStateStarting,
    FileSharingStateSharing,
    FileSharingStateStopping,
};


@interface FileSharing : NSObject

@property (class, nonatomic, readonly) NSNotificationName didChangeNotification;

@property (nonatomic, readonly) FileSharingState state;
@property (nonatomic, readonly) BOOL isSharing;
@property (nonatomic, readonly) BOOL isChanging;
@property (nonatomic, readonly, nullable) NSError *error;

- (instancetype)initWithMusicRootDirectoryURL:(nullable NSURL *)musicRootDirectoryURL
                                   fileSystem:(id<FileSystem>)fileSystem NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithMusicRootDirectoryURL:(nullable NSURL *)musicRootDirectoryURL;
- (instancetype)init NS_UNAVAILABLE;

- (void)start;
- (void)startWithCompletion:(nullable void (^)(void))completion;
- (void)stop;
- (void)stopWithCompletion:(nullable void (^)(void))completion;

@end


NS_ASSUME_NONNULL_END


#endif
