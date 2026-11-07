#import "FileSystem.h"

@implementation FileSystemItemInfo

- (instancetype)initWithIsDirectory:(BOOL)isDirectory
                      isRegularFile:(BOOL)isRegularFile
                          isPackage:(BOOL)isPackage
                      localizedName:(nullable NSString *)localizedName {
    self = [super init];
    if (self) {
        _isDirectory = isDirectory;
        _isRegularFile = isRegularFile;
        _isPackage = isPackage;
        _localizedName = [localizedName copy];
    }
    return self;
}

@end

@implementation ResolvedBookmark

- (instancetype)initWithURL:(NSURL *)url isStale:(BOOL)isStale {
    self = [super init];
    if (self) {
        _url = [url copy];
        _isStale = isStale;
    }
    return self;
}

@end
