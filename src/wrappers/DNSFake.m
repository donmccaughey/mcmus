#import "DNSFake.h"


@interface DNSBrowseFake ()

@property (nonatomic, readwrite, nullable) dispatch_queue_t dispatchQueue;
@property (nonatomic, readwrite) BOOL isDeallocated;
@property (nonatomic, readonly) DNSServiceRef serviceRef;

@end


@implementation DNSBrowseFake {
    DNSServiceBrowseReply _callBack;
    void *_context;
}


- (instancetype)initWithFlags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                      regtype:(char const *)regtype
                       domain:(nullable char const *)domain
                     callBack:(DNSServiceBrowseReply)callBack
                      context:(nullable void *)context;
{
    self = [super init];
    if (!self) return nil;

    _flags = flags;
    _interfaceIndex = interfaceIndex;
    _regtype = [NSString stringWithUTF8String:regtype];
    _domain = domain ? [NSString stringWithUTF8String:domain] : nil;
    _callBack = callBack;
    _context = context;

    return self;
}


// The browse stands in for its own service ref; DNSFake keeps every browse
// alive so the ref stays valid after it is deallocated.
- (DNSServiceRef)serviceRef;
{
    return (DNSServiceRef)(__bridge void *)self;
}


- (void)addServiceName:(char const *)serviceName
        interfaceIndex:(uint32_t)interfaceIndex
               regtype:(char const *)regtype
           replyDomain:(char const *)replyDomain;
{
    [self replyWithFlags:kDNSServiceFlagsAdd
          interfaceIndex:interfaceIndex
               errorCode:kDNSServiceErr_NoError
             serviceName:serviceName
                 regtype:regtype
             replyDomain:replyDomain];
}


- (void)removeServiceName:(char const *)serviceName
           interfaceIndex:(uint32_t)interfaceIndex
                  regtype:(char const *)regtype
              replyDomain:(char const *)replyDomain;
{
    [self replyWithFlags:0
          interfaceIndex:interfaceIndex
               errorCode:kDNSServiceErr_NoError
             serviceName:serviceName
                 regtype:regtype
             replyDomain:replyDomain];
}


- (void)failWithErrorCode:(DNSServiceErrorType)errorCode;
{
    [self replyWithFlags:0
          interfaceIndex:0
               errorCode:errorCode
             serviceName:NULL
                 regtype:NULL
             replyDomain:NULL];
}


- (void)replyWithFlags:(DNSServiceFlags)flags
        interfaceIndex:(uint32_t)interfaceIndex
             errorCode:(DNSServiceErrorType)errorCode
           serviceName:(nullable char const *)serviceName
               regtype:(nullable char const *)regtype
           replyDomain:(nullable char const *)replyDomain;
{
    NSAssert(!_isDeallocated, @"Expected no reply to a deallocated browse");
    _callBack(
        self.serviceRef,
        flags,
        interfaceIndex,
        errorCode,
        serviceName,
        regtype,
        replyDomain,
        _context
    );
}


@end


@implementation DNSFake {
    NSMutableArray<DNSBrowseFake *> *_browses;
}


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _browses = [NSMutableArray new];

    return self;
}


- (nullable DNSBrowseFake *)browse;
{
    return _browses.lastObject;
}


- (DNSServiceErrorType)browse:(DNSServiceRef _Nullable *_Nonnull)serviceRef
                        flags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                      regtype:(char const *)regtype
                       domain:(nullable char const *)domain
                     callBack:(DNSServiceBrowseReply)callBack
                      context:(nullable void *)context;
{
    if (kDNSServiceErr_NoError != _browseError) return _browseError;

    DNSBrowseFake *browse = [[DNSBrowseFake alloc] initWithFlags:flags
                                                  interfaceIndex:interfaceIndex
                                                         regtype:regtype
                                                          domain:domain
                                                        callBack:callBack
                                                         context:context];
    [_browses addObject:browse];
    *serviceRef = browse.serviceRef;
    return kDNSServiceErr_NoError;
}


// No test fakes a resolve yet.
- (DNSServiceErrorType)resolve:(DNSServiceRef _Nullable *_Nonnull)serviceRef
                         flags:(DNSServiceFlags)flags
                interfaceIndex:(uint32_t)interfaceIndex
                          name:(char const *)name
                       regtype:(char const *)regtype
                        domain:(char const *)domain
                      callBack:(DNSServiceResolveReply)callBack
                       context:(nullable void *)context;
{
    return kDNSServiceErr_Unsupported;
}


- (DNSServiceErrorType)setDispatchQueue:(dispatch_queue_t)queue
                          forServiceRef:(DNSServiceRef)serviceRef;
{
    if (kDNSServiceErr_NoError != _setDispatchQueueError) {
        return _setDispatchQueueError;
    }

    [self browseForServiceRef:serviceRef].dispatchQueue = queue;
    return kDNSServiceErr_NoError;
}


- (void)deallocateServiceRef:(DNSServiceRef)serviceRef;
{
    DNSBrowseFake *browse = [self browseForServiceRef:serviceRef];
    NSAssert(!browse.isDeallocated, @"Expected one deallocation per browse");
    browse.isDeallocated = YES;
}


- (DNSBrowseFake *)browseForServiceRef:(DNSServiceRef)serviceRef;
{
    for (DNSBrowseFake *browse in _browses) {
        if (browse.serviceRef == serviceRef) return browse;
    }
    NSAssert(NO, @"Expected a service ref from this fake");
    return nil;
}


@end
