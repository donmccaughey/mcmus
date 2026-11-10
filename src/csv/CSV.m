#import "CSV.h"


NSErrorDomain const CSVErrorDomain = @"CSVErrorDomain";
NSString *const CSVErrorLineKey = @"CSVErrorLine";
NSString *const CSVErrorColumnKey = @"CSVErrorColumn";


typedef NS_ENUM(NSInteger, ParseState) {
    ParseStateFieldStart,
    ParseStateUnquoted,
    ParseStateQuoted,
    ParseStateAfterClosingQuote,
};


static NSError *
error_at(CSVErrorCode code, NSString *description, NSUInteger line, NSUInteger column)
{
    NSString *located = [NSString stringWithFormat:@"%@ at line %lu, column %lu.",
                         description, (unsigned long)line, (unsigned long)column];
    return [NSError errorWithDomain:CSVErrorDomain
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey: located,
                               CSVErrorLineKey: @(line),
                               CSVErrorColumnKey: @(column),
                           }];
}


static NSError *
invalid_utf8_error(NSUInteger line, NSUInteger column)
{
    return error_at(CSVErrorCodeInvalidUTF8, @"Invalid UTF-8 in field starting", line, column);
}


static NSError *
unterminated_quoted_field_error(NSUInteger line, NSUInteger column)
{
    return error_at(CSVErrorCodeUnterminatedQuotedField, @"Unterminated quoted field starting", line, column);
}


static NSError *
quote_in_unquoted_field_error(NSUInteger line, NSUInteger column)
{
    return error_at(CSVErrorCodeQuoteInUnquotedField, @"Double quote in unquoted field", line, column);
}


static NSError *
text_after_closing_quote_error(NSUInteger line, NSUInteger column)
{
    return error_at(CSVErrorCodeTextAfterClosingQuote, @"Text after closing quote", line, column);
}


static NSError *
inconsistent_field_count_error(NSUInteger count, NSUInteger expected, NSUInteger line)
{
    NSString *description = [NSString stringWithFormat:@"Record has %lu fields, expected %lu, starting",
                             (unsigned long)count, (unsigned long)expected];
    return error_at(CSVErrorCodeInconsistentFieldCount, description, line, 1);
}


static BOOL
is_utf8_continuation_byte(uint8_t byte)
{
    return (byte & 0xC0) == 0x80;
}


static BOOL
is_line_break(uint8_t byte)
{
    return byte == '\r' || byte == '\n';
}


@interface Parser : NSObject

- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable NSArray<NSArray<NSString *> *> *)parse;

@property (nonatomic, readonly, nullable) NSError *error;

@end


@implementation Parser
{
    NSData *_data;
    const uint8_t *_bytes;
    NSUInteger _length;
    NSUInteger _index;
    NSUInteger _line;
    NSUInteger _column;
    NSUInteger _recordLine;
    NSUInteger _fieldLine;
    NSUInteger _fieldColumn;
    BOOL _recordStarted;
    ParseState _state;
    NSMutableData *_field;
    NSMutableArray<NSString *> *_fields;
    NSMutableArray<NSArray<NSString *> *> *_records;
}


- (instancetype)initWithData:(NSData *)data;
{
    self = [super init];
    if ( ! self) return nil;

    _data = data;
    _bytes = data.bytes;
    _length = data.length;
    _line = 1;
    _column = 1;
    _state = ParseStateFieldStart;
    _field = [NSMutableData new];
    _fields = [NSMutableArray new];
    _records = [NSMutableArray new];

    return self;
}


- (nullable NSArray<NSArray<NSString *> *> *)parse;
{
    [self skipByteOrderMark];
    while (_index < _length && ! _error) {
        [self consumeByte:_bytes[_index]];
    }
    if ( ! _error) [self consumeEndOfInput];
    return _error ? nil : [_records copy];
}


- (void)skipByteOrderMark;
{
    static const uint8_t byteOrderMark[] = { 0xEF, 0xBB, 0xBF };
    if (_length < sizeof byteOrderMark) return;
    if (memcmp(_bytes, byteOrderMark, sizeof byteOrderMark) == 0) _index = sizeof byteOrderMark;
}


- (void)consumeByte:(uint8_t)byte;
{
    switch (_state) {
        case ParseStateFieldStart: [self consumeByteAtFieldStart:byte]; break;
        case ParseStateUnquoted: [self consumeByteInUnquotedField:byte]; break;
        case ParseStateQuoted: [self consumeByteInQuotedField:byte]; break;
        case ParseStateAfterClosingQuote: [self consumeByteAfterClosingQuote:byte]; break;
    }
}


- (void)consumeByteAtFieldStart:(uint8_t)byte;
{
    if ( ! _recordStarted) _recordLine = _line;
    _recordStarted = YES;
    _fieldLine = _line;
    _fieldColumn = _column;
    if (byte == '"') {
        _state = ParseStateQuoted;
        [self advance];
    } else {
        _state = ParseStateUnquoted;
        [self consumeByteInUnquotedField:byte];
    }
}


- (void)consumeByteInUnquotedField:(uint8_t)byte;
{
    if ([self consumeDelimiter:byte]) return;
    if (byte == '"') {
        _error = quote_in_unquoted_field_error(_line, _column);
    } else {
        [self appendByte:byte];
    }
}


- (void)consumeByteInQuotedField:(uint8_t)byte;
{
    if (byte == '"') {
        _state = ParseStateAfterClosingQuote;
        [self advance];
    } else {
        [self appendByte:byte];
    }
}


- (void)consumeByteAfterClosingQuote:(uint8_t)byte;
{
    if ([self consumeDelimiter:byte]) return;
    if (byte == '"') {
        _state = ParseStateQuoted;
        [self appendByte:byte];
    } else {
        _error = text_after_closing_quote_error(_line, _column);
    }
}


- (BOOL)consumeDelimiter:(uint8_t)byte;
{
    if (byte == ',') {
        [self endField];
        [self advance];
        return YES;
    }
    if (is_line_break(byte)) {
        [self endField];
        [self endRecord];
        [self consumeLineBreak];
        return YES;
    }
    return NO;
}


- (void)consumeEndOfInput;
{
    switch (_state) {
        case ParseStateQuoted:
            _error = unterminated_quoted_field_error(_fieldLine, _fieldColumn);
            break;
        case ParseStateFieldStart:
            if ( ! _recordStarted) break;
            // fall through: a record ending in a comma has a final empty field
        case ParseStateUnquoted:
        case ParseStateAfterClosingQuote:
            [self endField];
            [self endRecord];
            break;
    }
}


- (void)appendByte:(uint8_t)byte;
{
    [_field appendBytes:&byte length:1];
    [self advance];
}


- (BOOL)isCRLFAtIndex;
{
    return _bytes[_index] == '\r' && _index + 1 < _length && _bytes[_index + 1] == '\n';
}


- (void)consumeLineBreak;
{
    BOOL isCRLF = [self isCRLFAtIndex];
    [self advance];
    if (isCRLF) [self advance];
}


- (void)advance;
{
    uint8_t byte = _bytes[_index];
    BOOL endsLine = byte == '\n' || (byte == '\r' && ! [self isCRLFAtIndex]);
    _index++;
    if (endsLine) {
        _line++;
        _column = 1;
    } else if ( ! is_utf8_continuation_byte(byte)) {
        _column++;
    }
}


- (void)endField;
{
    NSString *field = [self fieldString];
    if ( ! field) {
        _error = invalid_utf8_error(_fieldLine, _fieldColumn);
        return;
    }
    [_fields addObject:field];
    _field.length = 0;
    _state = ParseStateFieldStart;
}


- (nullable NSString *)fieldString;
{
    if ( ! _field.length) return @"";
    return [[NSString alloc] initWithBytes:_field.bytes
                                    length:_field.length
                                  encoding:NSUTF8StringEncoding];
}


- (void)endRecord;
{
    if (_error) return;
    NSUInteger expectedCount = _records.firstObject.count;
    if (_records.count && _fields.count != expectedCount) {
        _error = inconsistent_field_count_error(_fields.count, expectedCount, _recordLine);
        return;
    }
    [_records addObject:[_fields copy]];
    [_fields removeAllObjects];
    _recordStarted = NO;
}

@end


NSArray<NSArray<NSString *> *> *
parseCSV(NSData *data, NSError **error)
{
    Parser *parser = [[Parser alloc] initWithData:data];
    NSArray<NSArray<NSString *> *> *records = [parser parse];
    if ( ! records && error) *error = parser.error;
    return records;
}


static NSCharacterSet *
characters_requiring_quotes(void)
{
    static NSCharacterSet *characters;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        characters = [NSCharacterSet characterSetWithCharactersInString:@",\"\r\n"];
    });
    return characters;
}


static NSString *
format_field(NSString *field)
{
    BOOL needsQuotes = [field rangeOfCharacterFromSet:characters_requiring_quotes()].location != NSNotFound;
    if ( ! needsQuotes) return field;
    NSString *escaped = [field stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
    return [NSString stringWithFormat:@"\"%@\"", escaped];
}


static NSString *
format_record(NSArray<NSString *> *record)
{
    NSMutableArray<NSString *> *fields = [NSMutableArray arrayWithCapacity:record.count];
    for (NSString *field in record) {
        [fields addObject:format_field(field)];
    }
    return [fields componentsJoinedByString:@","];
}


NSData *
formatCSV(NSArray<NSArray<NSString *> *> *records)
{
    NSMutableString *csv = [NSMutableString new];
    for (NSArray<NSString *> *record in records) {
        [csv appendString:format_record(record)];
        // The ending after the last record lets a record with one empty
        // field round-trip: without it that record formats as nothing.
        [csv appendString:@"\r\n"];
    }
    // Lossy conversion only affects unpaired surrogates, which have no UTF-8
    // encoding; it keeps the result non-nil.
    return [csv dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
}
