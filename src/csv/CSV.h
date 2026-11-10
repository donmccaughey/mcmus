#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const CSVErrorDomain;

typedef NS_ENUM(NSInteger, CSVErrorCode) {
    CSVErrorCodeInvalidUTF8 = 1,
    CSVErrorCodeUnterminatedQuotedField,
    CSVErrorCodeQuoteInUnquotedField,
    CSVErrorCodeTextAfterClosingQuote,
    CSVErrorCodeInconsistentFieldCount,
};

// NSNumber values, 1-based.
extern NSString *const CSVErrorLineKey;
extern NSString *const CSVErrorColumnKey;


// Parses RFC 4180 CSV, accepting CR, LF or CRLF as record endings and
// skipping a leading UTF-8 byte order mark. Every record must have the same
// number of fields as the first record.
NSArray<NSArray<NSString *> *> *_Nullable
parseCSV(NSData *data, NSError **error);

// Writes RFC 4180 CSV with CRLF after every record, including the last, and
// quotes only fields that contain a comma, a double quote, CR or LF. Every
// record must have at least one field: CSV cannot represent an empty record,
// so `@[]` would read back as `@[@""]`.
NSData *
formatCSV(NSArray<NSArray<NSString *> *> *records);


NS_ASSUME_NONNULL_END
