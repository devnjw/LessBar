#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Opens the same domain/container pair used by the system, after a file grant.
/// No visibility restriction or assessment session is created.
FOUNDATION_EXPORT NSUserDefaults * _Nullable LBCreateContainerPreferences(
    NSString *domain, NSURL *container, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
