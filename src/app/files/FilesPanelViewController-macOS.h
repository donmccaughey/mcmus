#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "MusicLibraryStore.h"

@protocol Clock;
@protocol FileSystem;
@protocol Network;

NS_ASSUME_NONNULL_BEGIN

@interface FilesPanelViewController : NSViewController

- (instancetype)initWithStore:(MusicLibraryStore *)store
                   fileSystem:(id<FileSystem>)fileSystem
                      network:(id<Network>)network
                        clock:(id<Clock>)clock NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSNibName)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil
    NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
