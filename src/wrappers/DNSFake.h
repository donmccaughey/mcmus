#import <Foundation/Foundation.h>

#import "DNS.h"

NS_ASSUME_NONNULL_BEGIN

// A browse or resolve started on a DNSFake.
@interface DNSOperationFake : NSObject

@property (nonatomic, readonly) DNSServiceFlags flags;
@property (nonatomic, readonly) uint32_t interfaceIndex;
@property (nonatomic, readonly, copy) NSString *regtype;
@property (nonatomic, readonly, copy, nullable) NSString *domain;
@property (nonatomic, readonly, nullable) dispatch_queue_t dispatchQueue;
@property (nonatomic, readonly) BOOL isDeallocated;

@end

// The replies call the operation's callback on the calling thread, so call
// them from the queue the callback expects. Replying to a deallocated
// operation is a programming error, as the real service never does.

@interface DNSBrowseFake : DNSOperationFake

- (void)addServiceName:(char const *)serviceName
        interfaceIndex:(uint32_t)interfaceIndex
               regtype:(char const *)regtype
           replyDomain:(char const *)replyDomain;

- (void)removeServiceName:(char const *)serviceName
           interfaceIndex:(uint32_t)interfaceIndex
                  regtype:(char const *)regtype
              replyDomain:(char const *)replyDomain;

- (void)failWithErrorCode:(DNSServiceErrorType)errorCode;

@end

@interface DNSResolveFake : DNSOperationFake

@property (nonatomic, readonly, copy) NSString *name;

- (void)resolveToTargetHostname:(char const *)targetHostname
                           port:(uint16_t)port;

- (void)failWithErrorCode:(DNSServiceErrorType)errorCode;

@end

@interface DNSFake : NSObject <DNS>

@property (nonatomic) DNSServiceErrorType browseError;
@property (nonatomic) DNSServiceErrorType resolveError;
@property (nonatomic) DNSServiceErrorType setDispatchQueueError;
// The most recently started browse.
@property (nonatomic, readonly, nullable) DNSBrowseFake *browse;
// The most recently started resolve.
@property (nonatomic, readonly, nullable) DNSResolveFake *resolve;

@end

NS_ASSUME_NONNULL_END
