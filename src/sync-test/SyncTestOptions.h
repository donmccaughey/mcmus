#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


extern NSString *const SyncTestUsage;


@interface SyncTestOptions : NSObject

@property (nonatomic, readonly) NSURL *musicDirectoryURL;
@property (nonatomic, readonly) NSURL *workingDirectoryURL;
@property (nonatomic, readonly) NSURL *manifestURL;
@property (nonatomic, readonly, copy, nullable) NSString *shareName;

// `arguments` starts with the program name, as `NSProcessInfo` gives it.
// Relative paths are resolved against the current directory, which is also
// the working directory when the `--workdir` option is not given. The
// manifest is `manifest.csv` in the working directory when the `--manifest`
// option is not given.
+ (nullable instancetype)optionsWithArguments:(NSArray<NSString *> *)arguments
                          currentDirectoryURL:(NSURL *)currentDirectoryURL
                                        error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END


#endif
