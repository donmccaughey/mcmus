#import <Foundation/Foundation.h>

#import "DNS.h"

NS_ASSUME_NONNULL_BEGIN

@interface DNSBrowseFake : NSObject

@property (nonatomic, readonly) DNSServiceFlags flags;
@property (nonatomic, readonly) uint32_t interfaceIndex;
@property (nonatomic, readonly, copy) NSString *regtype;
@property (nonatomic, readonly, copy, nullable) NSString *domain;
@property (nonatomic, readonly, nullable) dispatch_queue_t dispatchQueue;
@property (nonatomic, readonly) BOOL isDeallocated;

// The replies call the browse callback on the calling thread, so call them
// from the queue the callback expects. Replying to a deallocated browse is a
// programming error, as the real service never does.

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

@interface DNSFake : NSObject <DNS>

@property (nonatomic) DNSServiceErrorType browseError;
@property (nonatomic) DNSServiceErrorType setDispatchQueueError;
// The most recently started browse.
@property (nonatomic, readonly, nullable) DNSBrowseFake *browse;

@end

NS_ASSUME_NONNULL_END
