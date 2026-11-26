#import "NSURL+FileSyncing.h"


@implementation NSURL (FileSyncing)


- (NSURL *)manifestURL;
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:self
                                             resolvingAgainstBaseURL:YES];
    components.path = @"/manifest";
    return components.URL;
}


@end
