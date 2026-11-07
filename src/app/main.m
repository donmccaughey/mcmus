#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "MCMusAppDelegate-macOS.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // NSApplicationMain relies on a nib to instantiate the delegate, so
        // it is created here and kept alive for the life of the process.
        MCMusAppDelegate *delegate = [[MCMusAppDelegate alloc] init];
        NSApplication.sharedApplication.delegate = delegate;
        return NSApplicationMain(argc, argv);
    }
}
#else
#import <UIKit/UIKit.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"MCMusAppDelegate");
    }
}
#endif
