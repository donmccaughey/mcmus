#import <Foundation/Foundation.h>
#import <dns_sd.h>


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const DNSServiceErrorTypeDomain;


@interface NSError (FileSyncing)

+ (instancetype)dnsServiceErrorWithCode:(DNSServiceErrorType)code;

@end


NS_ASSUME_NONNULL_END
