#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


// A file sharing server located via Bonjour
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

// Compares (serviceName, serviceType, domain) as the same
// file sharing server may appear on multiple interfaces
- (BOOL)isSameFileShare:(FileShare *)other;

@end


NS_ASSUME_NONNULL_END
