#import "PreferencesReal.h"

static NSString *const musicRootDirectoryBookmarkKey = @"musicRootDirectoryBookmark";

@implementation PreferencesReal

- (nullable NSData *)getMusicRootDirectoryBookmark {
    return [[NSUserDefaults standardUserDefaults] dataForKey:musicRootDirectoryBookmarkKey];
}

- (void)setMusicRootDirectoryBookmark:(NSData *)bookmark {
    [[NSUserDefaults standardUserDefaults] setObject:bookmark forKey:musicRootDirectoryBookmarkKey];
}

@end
