//
//  Growler.h
//  Hermes
//
//  Created by Alex Crichton on 10/2/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Song.h"
#import <Growl/GrowlApplicationBridge.h>

@interface Growler : NSObject<GrowlApplicationBridgeDelegate>

+ (void) subscribe;
+ (void) unsubscribe;
+ (void) growl:(Song*)song withImage:(NSImage*)image;

- (void) growl:(Song*)song withImage:(NSImage*)image;

@end
