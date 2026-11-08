#import "NotificationCounter.h"

@implementation NotificationCounter

- (instancetype)initWithName:(NSNotificationName)name object:(nullable id)object {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notified) name:name object:object];
    }
    return self;
}

- (void)notified {
    _count++;
}

@end
