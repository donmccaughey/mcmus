#import <Foundation/Foundation.h>

#import "Audio.h"
#import "FileSystem.h"


NS_ASSUME_NONNULL_BEGIN


BOOL isDemoMode(void);
id<FileSystem> demoFileSystemWrapping(id<FileSystem> fileSystem);
id<Audio> demoAudioWrapping(id<Audio> audio);


NS_ASSUME_NONNULL_END
