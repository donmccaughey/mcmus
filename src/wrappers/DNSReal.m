#import "DNSReal.h"


@implementation DNSReal


- (DNSServiceErrorType)browse:(DNSServiceRef _Nullable *_Nonnull)serviceRef
                        flags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                      regtype:(char const *)regtype
                       domain:(nullable char const *)domain
                     callBack:(DNSServiceBrowseReply)callBack
                      context:(nullable void *)context;
{
    return DNSServiceBrowse(
        serviceRef, flags, interfaceIndex, regtype, domain, callBack, context
    );
}


- (DNSServiceErrorType)resolve:(DNSServiceRef _Nullable *_Nonnull)serviceRef
                         flags:(DNSServiceFlags)flags
                interfaceIndex:(uint32_t)interfaceIndex
                          name:(char const *)name
                       regtype:(char const *)regtype
                        domain:(char const *)domain
                      callBack:(DNSServiceResolveReply)callBack
                       context:(nullable void *)context;
{
    return DNSServiceResolve(
        serviceRef,
        flags,
        interfaceIndex,
        name,
        regtype,
        domain,
        callBack,
        context
    );
}


- (DNSServiceErrorType)setDispatchQueue:(dispatch_queue_t)queue
                          forServiceRef:(DNSServiceRef)serviceRef;
{
    return DNSServiceSetDispatchQueue(serviceRef, queue);
}


- (void)deallocateServiceRef:(DNSServiceRef)serviceRef;
{
    DNSServiceRefDeallocate(serviceRef);
}


@end
