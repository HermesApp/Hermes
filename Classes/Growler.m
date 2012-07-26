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
  [GrowlApplicationBridge setGrowlDelegate:self];
  return self;
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
                             clickContext:@YES
                               identifier:@"Hermes"];
}

/******************************************************************************
 * Implementation of GrowlApplicationDelegate
 ******************************************************************************/

- (NSDictionary*) registrationDictionaryForGrowl {
  NSArray *notifications = @[@"hermes-song", @"hermes-play"];
  NSDictionary *human_names = @{
    @"hermes-song": @"New Songs",
    @"hermes-play": @"Play/pause Events"
  };
  return @{
    GROWL_NOTIFICATIONS_ALL:                  notifications,
    GROWL_NOTIFICATIONS_DEFAULT:              notifications,
    GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES: human_names
  };
}

- (void) growlNotificationWasClicked:(id)clickContext {
  [[[NSApp delegate] window] orderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

@end
