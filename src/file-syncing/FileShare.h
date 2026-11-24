#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


@interface FileShare : NSObject

@property (nonatomic, readonly) NSUInteger interfaceIndex;
@property (nonatomic, readonly, copy) NSString *serviceName;
@property (nonatomic, readonly, copy) NSString *serviceType;
@property (nonatomic, readonly, copy) NSString *domain;

- (instancetype)initWithInterfaceIndex:(uint32_t)interfaceIndex
                           serviceName:(char const *)serviceName
                               regtype:(char const *)regtype
                           replyDomain:(char const *)replyDomain;

- (instancetype)init NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END
