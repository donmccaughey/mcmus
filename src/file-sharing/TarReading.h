#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


// Returns a `@[path, contents]` pair for each entry of a tar file, in the
// order of the tar file, or nil when the tar file cannot be read.
NSArray<NSArray *> *_Nullable readTar(NSData *data);

// Returns the mtime of each entry of a tar file as a `time_t` number, in the
// order of the tar file, or nil when the tar file cannot be read.
NSArray<NSNumber *> *_Nullable readTarModificationTimes(NSData *data);


NS_ASSUME_NONNULL_END
