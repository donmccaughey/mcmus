#import <Foundation/Foundation.h>

#import "Network.h"

NS_ASSUME_NONNULL_BEGIN

// Error codes in this domain are `DNSServiceErrorType` values.
extern NSErrorDomain const NetworkAdvertisementErrorDomain;

@interface NetworkReal : NSObject <Network>
@end

NS_ASSUME_NONNULL_END
