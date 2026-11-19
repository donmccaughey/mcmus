#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


// Returns a `@[path, contents]` pair for each entry of a tar file, in the
// order of the tar file, or nil when the tar file cannot be read.
NSArray<NSArray *> *_Nullable readTar(NSData *data);


NS_ASSUME_NONNULL_END
