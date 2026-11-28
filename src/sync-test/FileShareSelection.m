#import "FileShareSelection.h"

#import "FileShare.h"


static const FileShareSelection cancelled = {
    .kind = FileShareSelectionKindCancelled,
};
static const FileShareSelection invalid = {
    .kind = FileShareSelectionKindInvalid,
};


static BOOL is_all_ascii_digits(NSString *string)
{
    NSCharacterSet *nonDigits =
        [NSCharacterSet characterSetWithCharactersInString:@"0123456789"]
            .invertedSet;
    return string.length &&
        [string rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}


FileShareSelection parse_file_share_selection(
    NSString *_Nullable input, NSUInteger fileShareCount
)
{
    if (!input) return cancelled;

    NSString *answer = [input
        stringByTrimmingCharactersInSet:NSCharacterSet
                                            .whitespaceAndNewlineCharacterSet];
    if ([answer caseInsensitiveCompare:@"q"] == NSOrderedSame) return cancelled;
    if (!is_all_ascii_digits(answer)) return invalid;

    // Saturates on overflow, which the range check below then rejects.
    unsigned long long number = 0;
    [[NSScanner scannerWithString:answer] scanUnsignedLongLong:&number];
    if (number < 1 || number > fileShareCount) return invalid;

    return (FileShareSelection){
        .kind = FileShareSelectionKindSelected,
        .index = (NSUInteger)number - 1,
    };
}


FileShare *_Nullable first_file_share_named(
    NSArray<FileShare *> *fileShares, NSString *shareName
)
{
    for (FileShare *fileShare in fileShares) {
        if ([fileShare.serviceName isEqualToString:shareName]) return fileShare;
    }
    return nil;
}
