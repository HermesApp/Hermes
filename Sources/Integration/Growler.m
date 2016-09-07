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
#import "PlaybackController.h"
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

  if (PREF_KEY_INT(GROWL_TYPE) == GROWL_TYPE_OSX) {
    NSUserNotification *not = [[NSUserNotification alloc] init];
    [not setTitle:title];
    [not setInformativeText:description];
    [not setHasActionButton:YES];
    [not setActionButtonTitle: @"Skip"];
    
    // Make skip button visible for banner notifications (like in iTunes)
    // - Undocumented API.  Will only work if Apple keeps in NSUserNotivication
    //   class.  Otherwise, skip button will only appear if 'Alert' style
    //   notifications are used.
    // - see: https://github.com/indragiek/NSUserNotificationPrivate
    @try {
      [not setValue:@YES forKey:@"_showsButtons"];
    } @catch (NSException *e) {
      if ([e name] != NSUndefinedKeyException) @throw e;
    }
    
    // Skip action
    NSUserNotificationAction *skipAction =
      [NSUserNotificationAction actionWithIdentifier:@"next" title:@"Skip"];
    
    // Like/Dislike actions
    NSString *likeActionTitle =
      ([[song nrating] intValue] == 1) ? @"Remove Like" : @"Like";
    
    NSUserNotificationAction *likeAction =
      [NSUserNotificationAction actionWithIdentifier:@"like" title:likeActionTitle];
    NSUserNotificationAction *dislikeAction =
      [NSUserNotificationAction actionWithIdentifier:@"dislike" title:@"Dislike"];
    
    [not setAdditionalActions: @[skipAction,likeAction,dislikeAction]];
    
    if ([not respondsToSelector:@selector(setContentImage:)]) {
      // Set album art where app icon is (like in iTunes)
      // - Undocumented API.  Will only work if Apple keeps in NSUserNotivication
      //   class.  Otherwise, skip button will only appear if 'Alert' style
      //   notifications are used.
      // - see: https://github.com/indragiek/NSUserNotificationPrivate
      @try {
        [not setValue:[[NSImage alloc] initWithData:image] forKey:@"_identityImage"];
      } @catch (NSException *e) {
        if ([e name] != NSUndefinedKeyException) @throw e;
        [not setContentImage:[[NSImage alloc] initWithData:image]];
      }
    }
    
    NSUserNotificationCenter *center =
        [NSUserNotificationCenter defaultUserNotificationCenter];
    [not setDeliveryDate:[NSDate date]];
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
  
  PlaybackController *playback = [[NSApp delegate] playback];
  NSString *actionID = [[notification additionalActivationAction] identifier];
  
  switch([notification activationType]) {
    case NSUserNotificationActivationTypeActionButtonClicked:
      
      // Skip button pressed
      [playback next:self];
      break;
      
    case NSUserNotificationActivationTypeAdditionalActionClicked:
      
      // One of the drop down buttons was pressed
      if ([actionID isEqualToString:@"like"]) {
        [playback like:self];
      } else if ([actionID isEqualToString:@"dislike"]) {
        [playback dislike:self];
      } else if ([actionID isEqualToString:@"next"]) {
        [playback next:self];
      }
      break;
      
    case NSUserNotificationActivationTypeContentsClicked:
      // Banner was clicked, so bring up and focus main UI
      [[[NSApp delegate] window] orderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
      break;
      
    default:
      // Any other action
      break;
      
  }
  // Only way to get this notification to be removed from center
  [center removeAllDeliveredNotifications];
}



@end
