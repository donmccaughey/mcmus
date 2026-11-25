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
    NSAssert(serviceName[0], @"Expected non-empty serviceName");
    NSAssert(regtype, @"Expected non-NULL regtype");
    NSAssert(regtype[0], @"Expected non-empty regtype");
    NSAssert(replyDomain, @"Expected non-NULL replyDomain");
    NSAssert(replyDomain[0], @"Expected non-empty replyDomain");

    NSString *serviceNameString = [NSString stringWithUTF8String:serviceName];
    NSAssert(serviceNameString, @"Expected serviceName to be UTF-8");

    NSString *serviceType = [NSString stringWithUTF8String:regtype];
    NSAssert(serviceType, @"Expected regtype to be UTF-8");

    NSString *domain = [NSString stringWithUTF8String:replyDomain];
    NSAssert(domain, @"Expected replyDomain to be UTF-8");

    return [self initWithInterfaceIndex:(NSUInteger)interfaceIndex
                            serviceName:serviceNameString
                            serviceType:serviceType
                                 domain:domain];
}


- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (BOOL)isSameFileShare:(FileShare *)other;
{
    return [self.serviceName isEqualToString:other.serviceName] &&
        [self.serviceType isEqualToString:other.serviceType] &&
        [self.domain isEqualToString:other.domain];
}


- (NSUInteger)hash;
{
    return self.interfaceIndex ^ self.serviceName.hash ^ self.serviceType.hash
        ^ self.domain.hash;
}


- (BOOL)isEqual:(id)object;
{
    if (self == object) return YES;
    if (![object isKindOfClass:[FileShare class]]) return NO;

    FileShare *other = object;
    return self.interfaceIndex == other.interfaceIndex &&
        [self isSameFileShare:other];
}

@end
