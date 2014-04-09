#import <SystemConfiguration/SCNetworkReachability.h>

@interface NetworkConnection : NSObject {
  SCNetworkReachabilityRef reachability;
}

@end
