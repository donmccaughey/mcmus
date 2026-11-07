#import "FileSystemFakeErrorMatching.h"

#import "FileSystemFake.h"

NSString *_Nullable fileSystemFakeErrorPath(NSError *error) {
    if (![error.domain isEqualToString:FileSystemFakeErrorDomain]
        || error.code != FileSystemFakeErrorCodeOperationFailed) {
        return nil;
    }
    return error.userInfo[NSFilePathErrorKey];
}

NSArray<NSString *> *fileSystemFakeErrorPaths(NSArray<NSError *> *errors) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSError *error in errors) {
        NSString *path = fileSystemFakeErrorPath(error);
        if (path) {
            [paths addObject:path];
        }
    }
    return paths;
}
