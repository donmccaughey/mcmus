#import "DNSFake.h"


@interface DNSOperationFake ()

@property (nonatomic, readwrite, nullable) dispatch_queue_t dispatchQueue;
@property (nonatomic, readwrite) BOOL isDeallocated;
@property (nonatomic, readonly) DNSServiceRef serviceRef;
@property (nonatomic, readonly, nullable) void *context;

@end


@implementation DNSOperationFake


- (instancetype)initWithFlags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                      regtype:(char const *)regtype
                       domain:(nullable char const *)domain
                      context:(nullable void *)context;
{
    self = [super init];
    if (!self) return nil;

    _flags = flags;
    _interfaceIndex = interfaceIndex;
    _regtype = [NSString stringWithUTF8String:regtype];
    _domain = domain ? [NSString stringWithUTF8String:domain] : nil;
    _context = context;

    return self;
}


// The operation stands in for its own service ref; DNSFake keeps every
// operation alive so the ref stays valid after it is deallocated.
- (DNSServiceRef)serviceRef;
{
    return (DNSServiceRef)(__bridge void *)self;
}


@end


@implementation DNSBrowseFake {
    DNSServiceBrowseReply _callBack;
}


- (instancetype)initWithFlags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                      regtype:(char const *)regtype
                       domain:(nullable char const *)domain
                     callBack:(DNSServiceBrowseReply)callBack
                      context:(nullable void *)context;
{
    self = [super initWithFlags:flags
                 interfaceIndex:interfaceIndex
                        regtype:regtype
                         domain:domain
                        context:context];
    if (!self) return nil;

    _callBack = callBack;

    return self;
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
    NSAssert(!self.isDeallocated, @"Expected no reply to a deallocated browse");
    _callBack(
        self.serviceRef,
        flags,
        interfaceIndex,
        errorCode,
        serviceName,
        regtype,
        replyDomain,
        self.context
    );
}


@end


@implementation DNSResolveFake {
    DNSServiceResolveReply _callBack;
}


- (instancetype)initWithFlags:(DNSServiceFlags)flags
               interfaceIndex:(uint32_t)interfaceIndex
                         name:(char const *)name
                      regtype:(char const *)regtype
                       domain:(char const *)domain
                     callBack:(DNSServiceResolveReply)callBack
                      context:(nullable void *)context;
{
    self = [super initWithFlags:flags
                 interfaceIndex:interfaceIndex
                        regtype:regtype
                         domain:domain
                        context:context];
    if (!self) return nil;

    _name = [NSString stringWithUTF8String:name];
    _callBack = callBack;

    return self;
}


- (void)resolveToTargetHostname:(char const *)targetHostname
                           port:(uint16_t)port;
{
    [self replyWithErrorCode:kDNSServiceErr_NoError
                targetHostname:targetHostname
        portInNetworkByteOrder:htons(port)];
}


- (void)failWithErrorCode:(DNSServiceErrorType)errorCode;
{
    [self replyWithErrorCode:errorCode
                targetHostname:NULL
        portInNetworkByteOrder:0];
}


- (void)replyWithErrorCode:(DNSServiceErrorType)errorCode
            targetHostname:(nullable char const *)targetHostname
    portInNetworkByteOrder:(uint16_t)portInNetworkByteOrder;
{
    NSAssert(
        !self.isDeallocated, @"Expected no reply to a deallocated resolve"
    );
    char const *fullServiceDomainName = NULL;
    uint16_t txtRecordLen = 0;
    unsigned char const *txtRecord = NULL;
    _callBack(
        self.serviceRef,
        0,
        self.interfaceIndex,
        errorCode,
        fullServiceDomainName,
        targetHostname,
        portInNetworkByteOrder,
        txtRecordLen,
        txtRecord,
        self.context
    );
}


@end


@implementation DNSFake {
    NSMutableArray<DNSOperationFake *> *_operations;
}


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _operations = [NSMutableArray new];

    return self;
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

    _browse = [[DNSBrowseFake alloc] initWithFlags:flags
                                    interfaceIndex:interfaceIndex
                                           regtype:regtype
                                            domain:domain
                                          callBack:callBack
                                           context:context];
    [_operations addObject:_browse];
    *serviceRef = _browse.serviceRef;
    return kDNSServiceErr_NoError;
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
    if (kDNSServiceErr_NoError != _resolveError) return _resolveError;

    _resolve = [[DNSResolveFake alloc] initWithFlags:flags
                                      interfaceIndex:interfaceIndex
                                                name:name
                                             regtype:regtype
                                              domain:domain
                                            callBack:callBack
                                             context:context];
    [_operations addObject:_resolve];
    *serviceRef = _resolve.serviceRef;
    return kDNSServiceErr_NoError;
}


- (DNSServiceErrorType)setDispatchQueue:(dispatch_queue_t)queue
                          forServiceRef:(DNSServiceRef)serviceRef;
{
    if (kDNSServiceErr_NoError != _setDispatchQueueError) {
        return _setDispatchQueueError;
    }

    [self operationForServiceRef:serviceRef].dispatchQueue = queue;
    return kDNSServiceErr_NoError;
}


- (void)deallocateServiceRef:(DNSServiceRef)serviceRef;
{
    DNSOperationFake *operation = [self operationForServiceRef:serviceRef];
    NSAssert(
        !operation.isDeallocated, @"Expected one deallocation per service ref"
    );
    operation.isDeallocated = YES;
}


- (DNSOperationFake *)operationForServiceRef:(DNSServiceRef)serviceRef;
{
    for (DNSOperationFake *operation in _operations) {
        if (operation.serviceRef == serviceRef) return operation;
    }
    NSAssert(NO, @"Expected a service ref from this fake");
    return nil;
}


@end
