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
#import "Pandora/Song.h"

@implementation Growler

- (id) init {
  PREF_OBSERVE_VALUE(self, PLEASE_GROWL);
  return self;
}

- (void) dealloc {
  PREF_UNOBSERVE_VALUES(self, PLEASE_GROWL);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
      change:(NSDictionary *)change context:(void *)context {
  if (PREF_KEY_BOOL(PLEASE_GROWL)) {
    [GrowlApplicationBridge setGrowlDelegate:self];
  }
}

- (void) growl:(Song*)song withImage:(NSImage*)image isNew:(BOOL)n {
  if (!PREF_KEY_BOOL(PLEASE_GROWL) ||
      (n && !PREF_KEY_BOOL(PLEASE_GROWL_NEW)) ||
      (!n && !PREF_KEY_BOOL(PLEASE_GROWL_PLAY))) {
    return;
  }

  NSString *title = [song title];
  NSString *description = [song artist];
  description = [description stringByAppendingString:@"\n"];
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
                               identifier:@"Hermes"];
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
