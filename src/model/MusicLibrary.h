#import <Foundation/Foundation.h>


@class Folder;
@class Track;


NS_ASSUME_NONNULL_BEGIN


@interface MusicLibrary : NSObject

@property (nonatomic, readonly) Folder *rootFolder;
@property (nonatomic, readonly) BOOL isEmpty;

- (instancetype)initWithRootFolder:(Folder *)rootFolder NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

- (NSArray<Track *> *)getTracks;

@end


NS_ASSUME_NONNULL_END
