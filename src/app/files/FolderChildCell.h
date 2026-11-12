#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

@interface FolderChildCell : UITableViewCell

@property (class, nonatomic, readonly) NSString *reuseIdentifier;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier
    NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)show:(id<FolderChild>)child
       onAdd:(void (^)(void))onAdd
      onOpen:(void (^)(void))onOpen;

@end

NS_ASSUME_NONNULL_END
#endif
