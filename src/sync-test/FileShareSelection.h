#import <Foundation/Foundation.h>


@class FileShare;

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, FileShareSelectionKind) {
    FileShareSelectionKindSelected,
    FileShareSelectionKindCancelled,
    FileShareSelectionKindInvalid,
};


typedef struct {
    FileShareSelectionKind kind;
    // Zero-based, and meaningful only when `kind` is `Selected`.
    NSUInteger index;
} FileShareSelection;


// `input` is one line of what the user typed in answer to a list numbered
// from 1, or nil at end of input.
FileShareSelection parse_file_share_selection(
    NSString *_Nullable input, NSUInteger fileShareCount
);

// Compares service names exactly: case-sensitive, with no trimming or Unicode
// normalization.
FileShare *_Nullable first_file_share_named(
    NSArray<FileShare *> *fileShares, NSString *shareName
);


NS_ASSUME_NONNULL_END
