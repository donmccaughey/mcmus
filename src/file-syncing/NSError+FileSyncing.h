#import <Foundation/Foundation.h>
#import <dns_sd.h>


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const DNSServiceErrorTypeDomain;
extern NSErrorDomain const HTTPStatusErrorDomain;


@interface NSError (FileSyncing)

+ (instancetype)dnsServiceErrorWithCode:(DNSServiceErrorType)code;

+ (instancetype)httpStatusErrorForResponse:(NSHTTPURLResponse *)response;

@end


NS_ASSUME_NONNULL_END
