#import <XCTest/XCTest.h>

#import "CSV.h"


static NSData *utf8(NSString *string)
{
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}


static NSString *string(NSData *data)
{
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


@interface CSVTests : XCTestCase
@end


@implementation CSVTests


#pragma mark - parseCSV() tests


- (void)testParseRecords;
{
    NSError *error = nil;
    CSVRecords records = parseCSV(utf8(@"a,b\r\nc,d\r\n"), &error);

    XCTAssertNil(error);
    XCTAssertEqualObjects((@[@[@"a", @"b"], @[@"c", @"d"]]), records);
}


- (void)testParseWithoutTrailingLineEnding;
{
    CSVRecords records = parseCSV(utf8(@"a,b\r\nc,d"), NULL);

    XCTAssertEqualObjects((@[@[@"a", @"b"], @[@"c", @"d"]]), records);
}


- (void)testParseLFEndings;
{
    CSVRecords records = parseCSV(utf8(@"a\nb\n"), NULL);

    XCTAssertEqualObjects((@[@[@"a"], @[@"b"]]), records);
}


- (void)testParseCREndings;
{
    CSVRecords records = parseCSV(utf8(@"a\rb\r"), NULL);

    XCTAssertEqualObjects((@[@[@"a"], @[@"b"]]), records);
}


- (void)testParseMixedEndings;
{
    CSVRecords records = parseCSV(utf8(@"a\r\nb\nc\rd"), NULL);

    XCTAssertEqualObjects((@[@[@"a"], @[@"b"], @[@"c"], @[@"d"]]), records);
}


- (void)testParseLFCRIsTwoEndings;
{
    CSVRecords records = parseCSV(utf8(@"a\n\rb"), NULL);

    XCTAssertEqualObjects((@[@[@"a"], @[@""], @[@"b"]]), records);
}


- (void)testParseEmptyData;
{
    NSError *error = nil;
    CSVRecords records = parseCSV([NSData data], &error);

    XCTAssertNil(error);
    XCTAssertEqualObjects((@[]), records);
}


- (void)testParseLoneLineEndingIsOneEmptyField;
{
    CSVRecords records = parseCSV(utf8(@"\n"), NULL);

    XCTAssertEqualObjects((@[@[@""]]), records);
}


- (void)testParseBlankLine;
{
    CSVRecords records = parseCSV(utf8(@"a\n\nb\n"), NULL);

    XCTAssertEqualObjects((@[@[@"a"], @[@""], @[@"b"]]), records);
}


- (void)testParseEmptyFields;
{
    CSVRecords records = parseCSV(utf8(@"a,,b\n,,\n"), NULL);

    XCTAssertEqualObjects((@[@[@"a", @"", @"b"], @[@"", @"", @""]]), records);
}


- (void)testParseTrailingComma;
{
    CSVRecords records = parseCSV(utf8(@"a,"), NULL);

    XCTAssertEqualObjects((@[@[@"a", @""]]), records);
}


- (void)testParsePreservesSpaces;
{
    CSVRecords records = parseCSV(utf8(@" a , b \n"), NULL);

    XCTAssertEqualObjects((@[@[@" a ", @" b "]]), records);
}


- (void)testParseQuotedFieldWithComma;
{
    CSVRecords records = parseCSV(utf8(@"\"a,b\",c\n"), NULL);

    XCTAssertEqualObjects((@[@[@"a,b", @"c"]]), records);
}


- (void)testParseQuotedFieldWithDoubledQuote;
{
    CSVRecords records = parseCSV(utf8(@"\"say \"\"hi\"\"\",\"\"\"\"\n"), NULL);

    XCTAssertEqualObjects((@[@[@"say \"hi\"", @"\""]]), records);
}


- (void)testParseQuotedFieldWithLineBreaks;
{
    CSVRecords records =
        parseCSV(utf8(@"\"a\nb\",\"c\rd\",\"e\r\nf\"\n"), NULL);

    XCTAssertEqualObjects((@[@[@"a\nb", @"c\rd", @"e\r\nf"]]), records);
}


- (void)testParseQuotedEmptyField;
{
    CSVRecords records = parseCSV(utf8(@"\"\",a\n"), NULL);

    XCTAssertEqualObjects((@[@[@"", @"a"]]), records);
}


- (void)testParseQuotedFieldAtEndOfInput;
{
    CSVRecords records = parseCSV(utf8(@"a,\"b\""), NULL);

    XCTAssertEqualObjects((@[@[@"a", @"b"]]), records);
}


- (void)testParseNonASCII;
{
    CSVRecords records =
        parseCSV(utf8(@"Björk,Sigur Rós\n東京,\"日本,語\"\n"), NULL);

    XCTAssertEqualObjects(
        (@[@[@"Björk", @"Sigur Rós"], @[@"東京", @"日本,語"]]), records
    );
}


- (void)testParseSkipsByteOrderMark;
{
    NSMutableData *data = [NSMutableData dataWithBytes:"\xEF\xBB\xBF" length:3];
    [data appendData:utf8(@"a,b\n")];

    CSVRecords records = parseCSV(data, NULL);

    XCTAssertEqualObjects((@[@[@"a", @"b"]]), records);
}


- (void)testParseUnterminatedQuotedField;
{
    NSError *error = nil;
    CSVRecords records = parseCSV(utf8(@"a,b\nc,\"d\ne"), &error);

    XCTAssertNil(records);
    XCTAssertEqualObjects(CSVErrorDomain, error.domain);
    XCTAssertEqual(CSVErrorCodeUnterminatedQuotedField, error.code);
    XCTAssertEqualObjects(@2, error.userInfo[CSVErrorLineKey]);
    XCTAssertEqualObjects(@3, error.userInfo[CSVErrorColumnKey]);
}


- (void)testParseQuoteInUnquotedField;
{
    NSError *error = nil;
    CSVRecords records = parseCSV(utf8(@"a,b\"c\n"), &error);

    XCTAssertNil(records);
    XCTAssertEqualObjects(CSVErrorDomain, error.domain);
    XCTAssertEqual(CSVErrorCodeQuoteInUnquotedField, error.code);
    XCTAssertEqualObjects(@1, error.userInfo[CSVErrorLineKey]);
    XCTAssertEqualObjects(@4, error.userInfo[CSVErrorColumnKey]);
}


- (void)testParseTextAfterClosingQuote;
{
    NSError *error = nil;
    CSVRecords records = parseCSV(utf8(@"\"a\"b,c\n"), &error);

    XCTAssertNil(records);
    XCTAssertEqualObjects(CSVErrorDomain, error.domain);
    XCTAssertEqual(CSVErrorCodeTextAfterClosingQuote, error.code);
    XCTAssertEqualObjects(@1, error.userInfo[CSVErrorLineKey]);
    XCTAssertEqualObjects(@4, error.userInfo[CSVErrorColumnKey]);
}


- (void)testParseInvalidUTF8;
{
    NSMutableData *data = [NSMutableData dataWithData:utf8(@"a,b\nc,")];
    [data appendBytes:"\xFF" length:1];
    [data appendData:utf8(@"\n")];

    NSError *error = nil;
    CSVRecords records = parseCSV(data, &error);

    XCTAssertNil(records);
    XCTAssertEqualObjects(CSVErrorDomain, error.domain);
    XCTAssertEqual(CSVErrorCodeInvalidUTF8, error.code);
    XCTAssertEqualObjects(@2, error.userInfo[CSVErrorLineKey]);
    XCTAssertEqualObjects(@3, error.userInfo[CSVErrorColumnKey]);
}


- (void)testParseInconsistentFieldCount;
{
    NSError *error = nil;
    CSVRecords records = parseCSV(utf8(@"a,b\n\"c\nd\"\ne,f,g\n"), &error);

    XCTAssertNil(records);
    XCTAssertEqualObjects(CSVErrorDomain, error.domain);
    XCTAssertEqual(CSVErrorCodeInconsistentFieldCount, error.code);
    XCTAssertEqualObjects(@2, error.userInfo[CSVErrorLineKey]);
    XCTAssertEqualObjects(@1, error.userInfo[CSVErrorColumnKey]);
}


- (void)testParseErrorWithNullErrorPointer;
{
    CSVRecords records = parseCSV(utf8(@"\"a"), NULL);

    XCTAssertNil(records);
}


- (void)testParseColumnCountsCharactersNotBytes;
{
    NSError *error = nil;
    CSVRecords records = parseCSV(utf8(@"東京,a\"\n"), &error);

    XCTAssertNil(records);
    XCTAssertEqualObjects(@5, error.userInfo[CSVErrorColumnKey]);
}


#pragma mark - generateCSV() tests


- (void)testGenerateRecords;
{
    NSData *data = generateCSV(@[@[@"a", @"b"], @[@"c", @"d"]]);

    XCTAssertEqualObjects(@"a,b\r\nc,d\r\n", string(data));
}


- (void)testGenerateEmptyFields;
{
    NSData *data = generateCSV(@[@[@"", @"a", @""], @[@""]]);

    XCTAssertEqualObjects(@",a,\r\n\r\n", string(data));
}


- (void)testGenerateQuotesFieldWithComma;
{
    NSData *data = generateCSV(@[@[@"a,b", @"c"]]);

    XCTAssertEqualObjects(@"\"a,b\",c\r\n", string(data));
}


- (void)testGenerateQuotesFieldWithQuote;
{
    NSData *data = generateCSV(@[@[@"say \"hi\"", @"\""]]);

    XCTAssertEqualObjects(@"\"say \"\"hi\"\"\",\"\"\"\"\r\n", string(data));
}


- (void)testGenerateQuotesFieldWithLineBreaks;
{
    NSData *data = generateCSV(@[@[@"a\nb", @"c\rd", @"e\r\nf"]]);

    XCTAssertEqualObjects(@"\"a\nb\",\"c\rd\",\"e\r\nf\"\r\n", string(data));
}


- (void)testGenerateLeavesSpacesUnquoted;
{
    NSData *data = generateCSV(@[@[@" a ", @"b c"]]);

    XCTAssertEqualObjects(@" a ,b c\r\n", string(data));
}


- (void)testGenerateNoRecords;
{
    NSData *data = generateCSV(@[]);

    XCTAssertEqualObjects([NSData data], data);
}


- (void)testGenerateNonASCII;
{
    NSData *data = generateCSV(@[@[@"Björk", @"日本,語"]]);

    XCTAssertEqualObjects(utf8(@"Björk,\"日本,語\"\r\n"), data);
}


#pragma mark - round trip tests


- (void)testGenerateThenParseYieldsEqualRecords;
{
    CSVRecords source = @[
        @[@"path", @"size", @"hash"],
        @[@"Björk/Debut/Human Behaviour.mp3", @"12345", @"abc"],
        @[@"a,b", @"say \"hi\"", @""],
        @[@"line\nbreak", @"cr\rbreak", @"crlf\r\nbreak"],
        @[@" padded ", @"\"", @",\",\n"],
        @[@"", @"", @""],
    ];

    NSError *error = nil;
    CSVRecords records = parseCSV(generateCSV(source), &error);

    XCTAssertNil(error);
    XCTAssertEqualObjects(source, records);
}


- (void)testGenerateThenParseSingleEmptyField;
{
    CSVRecords source = @[@[@""], @[@""]];

    CSVRecords records = parseCSV(generateCSV(source), NULL);

    XCTAssertEqualObjects(source, records);
}


- (void)testParseThenGenerateNormalizesEndingsAndQuotes;
{
    NSData *source =
        utf8(@"\"path\",\"size\"\n\"a b\",\"1\"\r\"c,d\",2\r\n\"e\"\"f\",\" \""
        );

    NSError *error = nil;
    NSData *data = generateCSV(parseCSV(source, &error));

    XCTAssertNil(error);
    XCTAssertEqualObjects(
        @"path,size\r\na b,1\r\n\"c,d\",2\r\n\"e\"\"f\", \r\n", string(data)
    );
}


- (void)testParseThenGeneratePreservesCanonicalData;
{
    NSData *source =
        utf8(@"path,size\r\n\"a,b\",1\r\n\"say \"\"hi\"\"\",\"x\r\ny\"\r\n,\r\n"
        );

    NSData *data = generateCSV(parseCSV(source, NULL));

    XCTAssertEqualObjects(source, data);
}


@end
