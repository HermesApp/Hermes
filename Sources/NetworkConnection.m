/**
 * @file NetworkConnection.m
 * @brief Tester for network connectivity and notifies the main application when
 *        this becomes true
 *
 * This class is meant to have one instance of itself during runtime.
 */
#include <netinet/in.h>
#include <string.h>

#import <CoreFoundation/CFRunLoop.h>

#import "HermesAppDelegate.h"
#import "NetworkConnection.h"

@implementation NetworkConnection

/**
 * @brief Callback invoked when the network changes
 */
void NetworkCallback(SCNetworkReachabilityRef target,
                     SCNetworkReachabilityFlags flags,
                     void *info) {
  /* If the address 0.0.0.0 is considered 'local', then we've successfully
     connected to some network with an IP, and we're a candidate for retrying a
     currently pending request. This doesn't mean that we're guaranteed the
     request will succeed, but it's at least remotely possible that it can. */
  if (flags & kSCNetworkReachabilityFlagsIsLocalAddress) {
    [[NSApp delegate] tryRetry];
  }
}

- (id) init {
  /* We'll be testing against 0.0.0.0 */
  struct sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_len = sizeof(address);
  address.sin_family  = AF_INET;
  reachability = SCNetworkReachabilityCreateWithAddress(NULL,
                                                  (struct sockaddr*) &address);

  /* Asynchronously notify us of network reachability changes */
  BOOL success = SCNetworkReachabilityScheduleWithRunLoop(
    reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
  assert(success);
  success = SCNetworkReachabilitySetCallback(
    reachability, NetworkCallback, NULL);
  assert(success);

  return self;
}

- (void) dealloc {
  /* Removes ourselves from the run loop and move on */
  SCNetworkReachabilityUnscheduleFromRunLoop(
    reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
  CFRelease(reachability);
}

@end
