//
//  Growler.m
//  Hermes
//
//  Created by Alex Crichton on 10/2/11.
//

#import <Growl/Growl.h>
#import "Growler.h"

Growler *growler = nil;

@implementation Growler

+ (void) subscribe {
  if (growler == nil) {
    growler = [[Growler alloc] init];
    [GrowlApplicationBridge setGrowlDelegate:growler];
  }
}

+ (void) unsubscribe {
  growler = nil;
  [GrowlApplicationBridge setGrowlDelegate:nil];
}

+ (void) growl:(Song*)song withImage:(NSImage*)image {
  if (growler == nil) {
    return;
  }

  [growler growl:song withImage:image];
}

- (void) growl:(Song*)song withImage:(NSImage*)image {
  NSString *title = [song title];
  NSString *description = [song artist];
  description = [description stringByAppendingString:@" - "];
  description = [description stringByAppendingString:[song album]];

  /* To deliver the event that a notification was clicked, the click context
     must be serializable and all that whatnot. Right now, we don't need any
     state to pass between these two methods, so just make sure that there's
     something that's plist-encodable */
  [GrowlApplicationBridge notifyWithTitle:title
                              description:description
                         notificationName:@"hermes-song"
                                 iconData:[image TIFFRepresentation]
                                 priority:0
                                 isSticky:NO
                             clickContext:[NSNumber numberWithBool:YES]
                               identifier:[song musicId]];
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

- (void) growlNotificationWasClicked:(id)clickContext {
  [[[NSApp delegate] window] orderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

@end
