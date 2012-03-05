/**
 * @file Growler.h
 * @brief Growl integration for the rest of Hermes
 *
 * Provides unified access to displaying notifications for different kinds
 * of events without having to deal with Growl directly.
 */

#import <Growl/Growl.h>

#import "Growler.h"
#import "PreferencesController.h"

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

+ (void) growl:(Song*)song withImage:(NSImage*)image isNew:(BOOL)n {
  if (growler == nil) {
    return;
  }

  [growler growl:song withImage:image isNew:n];
}

- (void) growl:(Song*)song withImage:(NSImage*)image isNew:(BOOL)n {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ((n && ![defaults boolForKey:PLEASE_GROWL_NEW]) ||
      (!n && ![defaults boolForKey:PLEASE_GROWL_PLAY])) {
    return;
  }

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
                         notificationName:n ? @"hermes-song" : @"hermes-play"
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
  [notifications addObject:@"hermes-play"];
  [dict setObject:notifications forKey:GROWL_NOTIFICATIONS_ALL];
  [dict setObject:notifications forKey:GROWL_NOTIFICATIONS_DEFAULT];

  NSMutableDictionary *human_names = [NSMutableDictionary dictionary];
  [human_names setObject:@"hermes-song" forKey:@"New Songs"];
  [human_names setObject:@"hermes-play" forKey:@"Play/pause Events"];
  [dict setObject:human_names forKey:GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES];
  return dict;
}

- (void) growlNotificationWasClicked:(id)clickContext {
  [[[NSApp delegate] window] orderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

@end
