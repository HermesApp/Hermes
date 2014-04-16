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
  if (NSClassFromString(@"NSUserNotificationCenter") != nil) {
    NSUserNotificationCenter *center =
        [NSUserNotificationCenter defaultUserNotificationCenter];
    [center setDelegate:self];
  }
  return self;
}

- (void) growl:(Song*)song withImage:(NSData*)image isNew:(BOOL)n {
  // Unconditionally remove all notifications from notification center to behave like iTunes
  // notifications and does not fill the notification center with old song details.
  [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];

  if (!PREF_KEY_BOOL(PLEASE_GROWL) ||
      (n && !PREF_KEY_BOOL(PLEASE_GROWL_NEW)) ||
      (!n && !PREF_KEY_BOOL(PLEASE_GROWL_PLAY))) {
    return;
  }

  NSString *title = [song title];
  if ([[song nrating] intValue] == 1) {
	  title = [NSString stringWithFormat:@"%@ %@", NSAppKitVersionNumber >= NSAppKitVersionNumber10_7 ? @"👍" : @"❤", title];
  }
  NSString *description = [NSString stringWithFormat:@"%@\n%@", [song artist],
                                                     [song album]];

  if (NSClassFromString(@"NSUserNotification") != nil &&
      PREF_KEY_INT(GROWL_TYPE) == GROWL_TYPE_OSX) {
    //Class Center = NSClassFromString(@"NSUserNotificationCenter");
    NSUserNotification *not = [[NSUserNotification alloc] init];
    [not setTitle:title];
    [not setInformativeText:description];
    if([not respondsToSelector:@selector(setContentImage:)]) {
      not.contentImage = [[NSImage alloc] initWithData:image];
    }
    NSUserNotificationCenter *center =
        [NSUserNotificationCenter defaultUserNotificationCenter];
    [center scheduleNotification:not];
    return;
  }

  /* To deliver the event that a notification was clicked, the click context
     must be serializable and all that whatnot. Right now, we don't need any
     state to pass between these two methods, so just make sure that there's
     something that's plist-encodable */
  [GrowlApplicationBridge notifyWithTitle:title
                              description:description
                         notificationName:n ? @"hermes-song" : @"hermes-play"
                                 iconData:image
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

/******************************************************************************
 * Implementation of NSUserNotificationCenterDelegate
 ******************************************************************************/

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification {
  /* always show notifications, even if the application is active */
  return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {
  [[[NSApp delegate] window] orderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

@end
