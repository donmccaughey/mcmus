#import <Foundation/Foundation.h>

#import "Preferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesFake : NSObject <Preferences>

@property (nonatomic, copy, nullable) NSData *musicRootDirectoryBookmark;

- (instancetype)initWithMusicRootDirectoryBookmark:(nullable NSData *)musicRootDirectoryBookmark NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
