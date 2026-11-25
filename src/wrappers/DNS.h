#import <Foundation/Foundation.h>
#import <dns_sd.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DNS <NSObject>

- (DNSServiceErrorType)browse:(DNSServiceRef _Nullable *_Nonnull)serviceRef
                        flags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                      regtype:(char const *)regtype
                       domain:(nullable char const *)domain
                     callBack:(DNSServiceBrowseReply)callBack
                      context:(nullable void *)context;

- (DNSServiceErrorType)resolve:(DNSServiceRef _Nullable *_Nonnull)serviceRef
                         flags:(DNSServiceFlags)flags
                interfaceIndex:(uint32_t)interfaceIndex
                          name:(char const *)name
                       regtype:(char const *)regtype
                        domain:(char const *)domain
                      callBack:(DNSServiceResolveReply)callBack
                       context:(nullable void *)context;

- (DNSServiceErrorType)setDispatchQueue:(dispatch_queue_t)queue
                          forServiceRef:(DNSServiceRef)serviceRef;

- (void)deallocateServiceRef:(DNSServiceRef)serviceRef;

@end

NS_ASSUME_NONNULL_END
