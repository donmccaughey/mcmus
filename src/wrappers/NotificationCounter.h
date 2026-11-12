#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NotificationCounter : NSObject

@property (nonatomic, readonly) NSUInteger count;

- (instancetype)initWithName:(NSNotificationName)name
                      object:(nullable id)object NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
