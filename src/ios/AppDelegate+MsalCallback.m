#import "AppDelegate+MsalCallback.h"
#import <MSAL/MSAL.h>

@implementation AppDelegate (MsalCallback)

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [MSALPublicClientApplication handleMSALResponse:url
                                         sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
}

@end
