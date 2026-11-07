#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Preferences <NSObject>

- (nullable NSData *)getMusicRootDirectoryBookmark;
- (void)setMusicRootDirectoryBookmark:(NSData *)bookmark;

@end

NS_ASSUME_NONNULL_END
