#import "LoadResult.h"

@implementation LoadResult

- (instancetype)initWithLibrary:(MusicLibrary *)library
                         errors:(NSArray<NSError *> *)errors
{
    self = [super init];
    if (self) {
        _library = library;
        _errors = [errors copy];
    }
    return self;
}

@end
