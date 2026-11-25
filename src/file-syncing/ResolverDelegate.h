#import <Foundation/Foundation.h>


@class FileShare;


@protocol ResolverDelegate <NSObject>

- (void)didResolveFileShare:(FileShare *)fileShare withURL:(NSURL *)url;

- (void)didFailToResolveFileShare:(FileShare *)fileShare
                        withError:(NSError *)error;

@end
