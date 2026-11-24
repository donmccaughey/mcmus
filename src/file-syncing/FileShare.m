#import "FileShare.h"


@interface FileShare ()

- (instancetype)initWithInterfaceIndex:(NSUInteger)interfaceIndex
                           serviceName:(NSString *)serviceName
                           serviceType:(NSString *)serviceType
                                domain:(NSString *)domain
    NS_DESIGNATED_INITIALIZER;

@end


@implementation FileShare


- (instancetype)initWithInterfaceIndex:(NSUInteger)interfaceIndex
                           serviceName:(NSString *)serviceName
                           serviceType:(NSString *)serviceType
                                domain:(NSString *)domain;
{
    self = [super init];
    if (!self) return nil;

    _interfaceIndex = interfaceIndex;
    _serviceName = [serviceName copy];
    _serviceType = [serviceType copy];
    _domain = [domain copy];

    return self;
}


- (instancetype)initWithInterfaceIndex:(uint32_t)interfaceIndex
                           serviceName:(char const *)serviceName
                               regtype:(char const *)regtype
                           replyDomain:(char const *)replyDomain;
{
#if (NSUIntegerMax < UINT32_MAX)
#error uint32_t not convertable to NSUInteger without truncation
#endif

    NSAssert(serviceName, @"Expected non-NULL serviceName");
    NSAssert(regtype, @"Expected non-NULL regtype");
    NSAssert(replyDomain, @"Expected non-NULL replyDomain");

    return [self
        initWithInterfaceIndex:(NSUInteger)interfaceIndex
                   serviceName:[NSString stringWithUTF8String:serviceName]
                   serviceType:[NSString stringWithUTF8String:regtype]
                        domain:[NSString stringWithUTF8String:replyDomain]];
}


- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder;
{

    if (![coder containsValueForKey:@"interfaceIndex"]) return nil;
    int64_t interfaceIndex = [coder decodeInt64ForKey:@"interfaceIndex"];
    if (interfaceIndex < 0 || interfaceIndex > NSUIntegerMax) return nil;

    NSString *serviceName = [coder decodeObjectForKey:@"serviceName"];
    if (![serviceName isKindOfClass:[NSString class]]) return nil;

    NSString *serviceType = [coder decodeObjectForKey:@"serviceType"];
    if (![serviceType isKindOfClass:[NSString class]]) return nil;

    NSString *domain = [coder decodeObjectForKey:@"domain"];
    if (![domain isKindOfClass:[NSString class]]) return nil;

    return [self initWithInterfaceIndex:(NSUInteger)interfaceIndex
                            serviceName:serviceName
                            serviceType:serviceType
                                 domain:domain];
}


- (void)encodeWithCoder:(nonnull NSCoder *)coder;
{
    [coder encodeInt64:_interfaceIndex forKey:@"interfaceIndex"];
    [coder encodeObject:_serviceName forKey:@"serviceName"];
    [coder encodeObject:_serviceType forKey:@"serviceType"];
    [coder encodeObject:_domain forKey:@"domain"];
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


@end
