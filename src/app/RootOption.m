#import "RootOption.h"


#if TARGET_OS_OSX
NSURL *_Nullable rootOptionURL(NSArray<NSString *> *arguments)
{
    if ([arguments containsObject:@"--demo"]) {
        return nil;
    }
    NSUInteger option = [arguments indexOfObject:@"--root"];
    if (option == NSNotFound || option + 1 >= arguments.count) {
        return nil;
    }
    return [NSURL fileURLWithPath:arguments[option + 1] isDirectory:YES];
}
#endif
