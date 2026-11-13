#import "include/LBContainerPreferences.h"

@interface NSUserDefaults (LBContainerInitialization)
- (instancetype)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container;
@end

NSUserDefaults *LBCreateContainerPreferences(NSString *domain, NSURL *container, NSError **error) {
    SEL selector = NSSelectorFromString(@"_initWithSuiteName:container:");
    NSString *reason = @"Container-aware preferences are unavailable";
    @try {
        if ([NSUserDefaults instancesRespondToSelector:selector]) {
            return [[NSUserDefaults alloc] _initWithSuiteName:domain container:container];
        }
    } @catch (NSException *exception) {
        reason = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    if (error) {
        *error = [NSError errorWithDomain:@"LessBar.NativePreferences" code:1
            userInfo:@{NSLocalizedDescriptionKey: reason}];
    }
    return nil;
}
