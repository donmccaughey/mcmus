#import <Foundation/Foundation.h>


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


NS_ASSUME_NONNULL_END
