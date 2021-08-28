#import "AppDelegate.h"

@interface AppDelegate (MsalCallback)

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

/* AppDelegate_MsalCallback_h */
