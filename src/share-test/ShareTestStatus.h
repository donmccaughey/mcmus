#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@class FileSharing;


NS_ASSUME_NONNULL_BEGIN


// Mirrors the text that `ShareStatusBarView` shows in the app.
NSString *share_test_status_text(FileSharing *fileSharing);


NS_ASSUME_NONNULL_END


#endif
