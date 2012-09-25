//
//  Growler.h
//  Hermes
//

#import <Growl/GrowlApplicationBridge.h>

@class Song;

#define GROWLER [[NSApp delegate] growler]

@interface Growler : NSObject<GrowlApplicationBridgeDelegate,
                              NSUserNotificationCenterDelegate>

- (void) growl:(Song*)song withImage:(NSData*)image isNew:(BOOL) n;

@end
