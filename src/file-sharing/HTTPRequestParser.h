#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


@interface HTTPRequest : NSObject

@property (nonatomic, readonly, copy) NSString *method;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy, nullable) NSString *userAgent;
@property (nonatomic, readonly, copy, nullable) NSString *contentType;
// False when the request left out the header, which reads as an empty body.
@property (nonatomic, readonly) BOOL hasContentLength;
@property (nonatomic, readonly, copy) NSData *body;
// True when the client asked for the connection to close after the response.
@property (nonatomic, readonly) BOOL closesConnection;

@end


typedef NS_ENUM(NSInteger, HTTPRequestParserState) {
    HTTPRequestParserStateIncomplete,
    HTTPRequestParserStateComplete,
    HTTPRequestParserStateInvalid,
};


// Parses one request from the bytes of a connection, then is discarded.
@interface HTTPRequestParser : NSObject

@property (nonatomic, readonly) HTTPRequestParserState state;
@property (nonatomic, readonly, nullable) HTTPRequest *request;
// Once the request is complete, the bytes that followed it: the start of the
// client's next request on the same connection.
@property (nonatomic, readonly) NSData *excessData;

- (void)append:(NSData *)data;

@end


NS_ASSUME_NONNULL_END


#endif
