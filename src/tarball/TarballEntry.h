#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


@interface TarballEntry : NSObject

@property (nonatomic, readonly, copy) NSString *relativePath;
@property (nonatomic, readonly) unsigned long long size;
@property (nonatomic, readonly) time_t mtime;

- (instancetype)initWithRelativePath:(NSString *)relativePath
                                size:(unsigned long long)size
                               mtime:(time_t)mtime NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END
