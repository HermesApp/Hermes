//
//  Growler.h
//  Hermes
//

#import "Song.h"
#import <Growl/GrowlApplicationBridge.h>

@interface Growler : NSObject<GrowlApplicationBridgeDelegate>

+ (void) subscribe;
+ (void) unsubscribe;
+ (void) growl:(Song*)song withImage:(NSImage*)image;

- (void) growl:(Song*)song withImage:(NSImage*)image;

@end
