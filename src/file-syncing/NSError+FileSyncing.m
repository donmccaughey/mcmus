#import "NSError+FileSyncing.h"


NSErrorDomain const DNSServiceErrorTypeDomain = @"DNSServiceErrorTypeDomain";


@implementation NSError (FileSyncing)


+ (instancetype)dnsServiceErrorWithCode:(DNSServiceErrorType)code;
{
    return [NSError errorWithDomain:DNSServiceErrorTypeDomain
                               code:code
                           userInfo:nil];
}


@end
