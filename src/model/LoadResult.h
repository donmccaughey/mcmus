#import <Foundation/Foundation.h>

#import "MusicLibrary.h"

NS_ASSUME_NONNULL_BEGIN

@interface LoadResult : NSObject

@property (nonatomic, readonly) MusicLibrary *library;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;

- (instancetype)initWithLibrary:(MusicLibrary *)library
                         errors:(NSArray<NSError *> *)errors
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
