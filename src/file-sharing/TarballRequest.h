#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


@class HTTPRequest;
@class Manifest;
@class TarballEntry;


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const TarballRequestErrorDomain;

typedef NS_ENUM(NSInteger, TarballRequestErrorCode) {
    TarballRequestErrorCodeInvalidContentLength = 1,
    TarballRequestErrorCodeInvalidContentType,
    TarballRequestErrorCodeInvalidCSV,
    TarballRequestErrorCodeUnknownTrack,
    TarballRequestErrorCodeTarballTooBig,
};


// Returns an entry for each track that a POST `/files` request asks for, in
// the order it asks for them. The localized description of an error is the
// plain text body of the response to send.
NSArray<TarballEntry *> *_Nullable parseTarballRequest(
    HTTPRequest *request, Manifest *manifest, NSError **error);


NS_ASSUME_NONNULL_END


#endif
