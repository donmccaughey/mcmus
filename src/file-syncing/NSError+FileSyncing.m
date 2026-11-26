#import "NSError+FileSyncing.h"


NSErrorDomain const DNSServiceErrorTypeDomain = @"DNSServiceErrorTypeDomain";
NSErrorDomain const HTTPStatusErrorDomain = @"HTTPStatusErrorDomain";


@implementation NSError (FileSyncing)


+ (instancetype)dnsServiceErrorWithCode:(DNSServiceErrorType)code;
{
    return [NSError errorWithDomain:DNSServiceErrorTypeDomain
                               code:code
                           userInfo:nil];
}


+ (instancetype)httpStatusErrorForResponse:(NSHTTPURLResponse *)response;
{
    return [NSError errorWithDomain:HTTPStatusErrorDomain
                               code:response.statusCode
                           userInfo:nil];
}


@end
