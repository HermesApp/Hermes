//
//  Growler.m
//  Hermes
//
//  Created by Alex Crichton on 10/2/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Growl/Growl.h>
#import "Growler.h"

Growler *growler = nil;

@implementation Growler

+ (void) subscribe {
  if (growler != nil) {
    return;
  }
  
  growler = [[Growler alloc] init];
  [GrowlApplicationBridge setGrowlDelegate:growler];
}

+ (void) unsubscribe {
  if (growler == nil) {
    return;
  }
  
  [growler release];
  growler = nil;
  [GrowlApplicationBridge setGrowlDelegate:nil];
}

+ (void) growl:(Song *)song withImage:(NSImage *)image {
  if (growler == nil) {
    return;
  }
  
  [growler growl:song withImage:image];
}

- (void) growl:(Song *)song withImage:(NSImage *)image {
  NSString *description = [song artist];
  description = [description stringByAppendingString:@" - "];
  description = [description stringByAppendingString:[song album]];

  [GrowlApplicationBridge notifyWithTitle:[song title]
                              description:description
                         notificationName:@"hermes-song"
                                 iconData:[image TIFFRepresentation]
                                 priority:0
                                 isSticky:NO
                             clickContext:nil];
}

/******************************************************************************
 * Implementation of GrowlApplicationDelegate
 ******************************************************************************/

- (NSDictionary*) registrationDictionaryForGrowl {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSMutableArray *notifications = [NSMutableArray array];
  [notifications addObject:@"hermes-song"];
  [dict setObject:notifications forKey:GROWL_NOTIFICATIONS_ALL];
  [dict setObject:notifications forKey:GROWL_NOTIFICATIONS_DEFAULT];
  return dict;
}

@end
