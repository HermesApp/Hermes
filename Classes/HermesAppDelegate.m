/**
 * @file HermesAppDelegate.m
 * @brief Implementation of the AppDelegate for Hermes
 *
 * Contains startup routines, and other interfaces with the OS
 */

#import <AudioStreamer/AudioStreamer.h>

#import "AppleMediaKeyController.h"
#import "AuthController.h"
#import "Growler.h"
#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "Keychain.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "Scrobbler.h"
#import "StationController.h"
#import "StationsController.h"

@implementation HermesAppDelegate

@synthesize stations, auth, playback, pandora, window, history, station,
            growler, scrobbler;

- (id) init {
  if ((self = [super init])) {
    pandora = [[Pandora alloc] init];
  }
  return self;
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                    hasVisibleWindows:(BOOL)flag {
  if (!flag) {
    [window makeKeyAndOrderFront:nil];
  }

  return YES;
}

- (void) closeNewStationSheet {
  [NSApp endSheet:newStationSheet];
  [newStationSheet orderOut:self];
}

- (void) showNewStationSheet {
  [NSApp beginSheet: newStationSheet
     modalForWindow: window
      modalDelegate: self
     didEndSelector: NULL
        contextInfo: nil];
}

- (void) showLoader {
  [self setCurrentView:loadingView];
  [loadingIcon startAnimation:nil];
}

- (void) cacheAuth: (NSString*) username : (NSString*) password {
  [[NSUserDefaults standardUserDefaults] setObject:username forKey:USERNAME_KEY];
  KeychainSetItem(username, password);
}

- (void) setCurrentView:(NSView *)view {
  NSView *superview = [window contentView];

  if ([[superview subviews] count] > 0) {
    NSView *prev_view = [[superview subviews] objectAtIndex:0];
    if (prev_view == view) {
      return;
    }
    [[superview animator] replaceSubview:prev_view with:view];
  } else {
    [superview addSubview:view];
  }

  NSRect frame = [view frame];
  NSRect superFrame = [superview frame];
  frame.size.width = superFrame.size.width;
  frame.size.height = superFrame.size.height;
  [view setFrame:frame];
}

- (void) migrateDefaults:(NSUserDefaults*) defaults {
  NSMutableDictionary *map = [NSMutableDictionary dictionary];
  [map setObject:PLEASE_BIND_MEDIA forKey:@"hermes.please-bind-media"];
  [map setObject:PLEASE_SCROBBLE forKey:@"hermes.please-scrobble"];
  [map setObject:PLEASE_SCROBBLE_LIKES forKey:@"hermes.please-scrobble-likes"];
  [map setObject:ONLY_SCROBBLE_LIKED forKey:@"hermes.only-scrobble-likes"];
  [map setObject:PLEASE_GROWL forKey:@"hermes.please-growl"];
  [map setObject:PLEASE_GROWL_NEW forKey:@"hermes.please-growl-new"];
  [map setObject:PLEASE_GROWL_PLAY forKey:@"hermes.please-growl-play"];
  [map setObject:PLEASE_CLOSE_DRAWER forKey:@"hermes.please-close-drawer"];
  [map setObject:DRAWER_WIDTH forKey:@"hermes.drawer-width"];
  [map setObject:DESIRED_QUALITY forKey:@"hermes.audio-quality"];
  [map setObject:LAST_PREF_PANE forKey:@"hermes.last-pref-pane"];

  NSDictionary *d = [defaults dictionaryRepresentation];

  for (NSString *key in d) {
    NSString *newKey = [map objectForKey:key];
    if (newKey == nil) continue;
    [defaults setObject:[defaults objectForKey:key]
                 forKey:[map objectForKey:key]];
    [defaults removeObjectForKey:key];
  }

  NSString *s = [defaults objectForKey:@"hermes.audio-quality"];
  if (s == nil) return;
  if ([s isEqualToString:@"high"]) {
    [defaults setInteger:QUALITY_HIGH forKey:DESIRED_QUALITY];
  } else if ([s isEqualToString:@"med"]) {
    [defaults setInteger:QUALITY_MED forKey:DESIRED_QUALITY];
  } else if ([s isEqualToString:@"low"]) {
    [defaults setInteger:QUALITY_LOW forKey:DESIRED_QUALITY];
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  if ([window respondsToSelector:@selector(setRestorable:)]) {
    [window setRestorable:YES];
  }
  if ([window respondsToSelector:@selector(setRestorationClass:)]) {
    [window setRestorationClass:[self class]];
  }
  [NSApp activateIgnoringOtherApps:YES];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(handlePandoraError:)
    name:@"hermes.pandora-error"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(handleStreamError:)
    name:@"hermes.stream-error"
    object:nil];

  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(handlePandoraLoggedOut:)
   name:@"hermes.logged-out"
   object:[[NSApp delegate] pandora]];

  // See http://developer.apple.com/mac/library/qa/qa2004/qa1340.html
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
      selector: @selector(receiveSleepNote:)
      name: NSWorkspaceWillSleepNotification object: NULL];

  NSString *savedUsername = [self getCachedUsername];
  NSString *savedPassword = [self getCachedPassword];
  if (savedPassword == nil || savedUsername == nil) {
    [auth show];
  } else {
    [self showLoader];
    [pandora authenticate:savedUsername
                 password:savedPassword
                  request:nil];
  }

  NSMutableDictionary *app_defaults = [NSMutableDictionary dictionary];
  [app_defaults setObject:@"0" forKey:PLEASE_SCROBBLE];
  [app_defaults setObject:@"0" forKey:ONLY_SCROBBLE_LIKED];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL_PLAY];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL_NEW];
  [app_defaults setObject:@"1" forKey:PLEASE_BIND_MEDIA];
  [app_defaults setObject:@"0" forKey:PLEASE_CLOSE_DRAWER];
  [app_defaults setObject:[NSNumber numberWithInt:PROXY_SYSTEM]
                   forKey:ENABLED_PROXY];
  [app_defaults setObject:[NSNumber numberWithInt:QUALITY_MED]
                   forKey:DESIRED_QUALITY];
  [app_defaults setObject:[NSNumber numberWithInt:130] forKey:DRAWER_WIDTH];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults registerDefaults:app_defaults];
  [self migrateDefaults:defaults];
  [playback prepareFirst];
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
  NSMenu *menu = [[NSMenu alloc] init];
  NSMenuItem *menuItem;
  Song *song = [[playback playing] playing];
  if (song != nil) {
    [menu addItemWithTitle:@"Now Playing" action:nil keyEquivalent:@""];;
    [menu addItemWithTitle:[NSString stringWithFormat:@"   %@", [song title]]
                    action:nil
             keyEquivalent:@""];
    [menu addItemWithTitle:[NSString stringWithFormat:@"   %@", [song artist]]
                    action:nil
             keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
  }
  NSString *title;
  if ([[playback playing] isPaused] || song == nil) {
    title = @"Play";
  } else {
    title = @"Pause";
  }
  menuItem = [menu addItemWithTitle:title
                             action:@selector(playpause:)
                      keyEquivalent:@"p"];
  [menuItem setTarget:playback];
  menuItem = [menu addItemWithTitle:@"Next"
                             action:@selector(next:)
                      keyEquivalent:@"n"];
  [menuItem setTarget:playback];
  if ([[song nrating] intValue] == 1) {
    [menu addItemWithTitle:@"Liked" action:nil keyEquivalent:@""];
  } else {
    menuItem = [menu addItemWithTitle:@"Like"
                               action:@selector(like:)
                        keyEquivalent:@"l"];
    [menuItem setTarget:playback];
  }
  menuItem = [menu addItemWithTitle:@"Dislike"
                             action:@selector(dislike:)
                      keyEquivalent:@"d"];
  [menuItem setTarget:playback];
  return menu;
}

- (NSString*) getCachedUsername {
  return [[NSUserDefaults standardUserDefaults] stringForKey:USERNAME_KEY];
}

- (NSString*) getCachedPassword {
  return KeychainGetPassword([self getCachedUsername]);
}

- (void)applicationWillResignActive:(NSNotification *)aNotification {
  [playback saveState];
  [history saveSongs];
}

- (void) applicationWillTerminate: (NSNotification *)aNotification {
  [playback saveState];
  [history saveSongs];
}

- (void) receiveSleepNote: (NSNotification*) note {
  [[playback playing] pause];
}

- (void) handleStreamError: (NSNotification*) notification {
  lastStationErr = [notification object];
  [self setCurrentView:errorView];
  NSString *err = [lastStationErr streamNetworkError];
  [errorLabel setStringValue:err];
  [window orderFront:nil];
}

- (void) handlePandoraError: (NSNotification*) notification {
  NSDictionary *info = [notification userInfo];
  NSString *err  = [info objectForKey:@"error"];
  NSNumber *nscode = [info objectForKey:@"code"];
  NSLogd(@"error received %@", info);
  /* If this is a generic error (like a network error) it's possible to retry.
     Otherewise if it's a Pandora error (with a code listed) there's likely
     nothing we can do about it */
  [errorButton setHidden:FALSE];
  lastRequest = nil;

  if (nscode != nil) {
    int code = [nscode intValue];
    [errorButton setHidden:TRUE];

    switch (code) {
      case INVALID_AUTH_TOKEN: {
        NSString *user = [self getCachedUsername];
        NSString *pass = [self getCachedPassword];
        if (user == nil || pass == nil) {
          [[playback playing] pause];
          [auth authenticationFailed:notification];
        } else {
          [pandora logoutNoNotify];
          [pandora authenticate:user
                       password:pass
                        request:[info objectForKey:@"request"]];
        }
        return;
      }

      /* Oddly enough, the same error code is given our for invalid login
         information as is for invalid partner login information... */
      case INVALID_PARTNER_LOGIN:
      case INVALID_USERNAME:
      case INVALID_PASSWORD:
        [[playback playing] pause];
        [auth authenticationFailed:notification];
        return;

      case NO_SEEDS_LEFT:
        [station seedFailedDeletion:notification];
        return;

      default: {
        NSString *other = [Pandora errorString:code];
        if (other != nil && other != NULL) {
          err = other;
        }
        break;
      }
    }
  }

  lastRequest = [[notification userInfo] objectForKey:@"request"];
  [self setCurrentView:errorView];
  [errorLabel setStringValue:err];
  [window orderFront:nil];
}

- (void) retry:(id)sender {
  if (lastRequest != nil) {
    [pandora sendRequest:lastRequest];
    lastRequest = nil;
    [self showLoader];
  } else if (lastStationErr != nil) {
    [lastStationErr retry:NO];
    [playback show];
    lastStationErr = nil;
  }
}

- (void) tryRetry {
  if (lastRequest != nil || lastStationErr != nil) {
    [self retry:nil];
  }
}

- (void) handlePandoraLoggedOut: (NSNotification*) notification {
  [stations reset];
  [playback reset];

  /* Remove our credentials */
  [self cacheAuth:@"" :@""];
  [auth show];
}

+ (BOOL)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
  [PlaybackController setPlayOnStart:NO];
  completionHandler(nil, nil);
  return YES;
}

- (NSString*) stateDirectory:(NSString *)file {
  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSString *folder = @"~/Library/Application Support/Hermes/";
  folder = [folder stringByExpandingTildeInPath];
  BOOL hasFolder = YES;

  if ([fileManager fileExistsAtPath: folder] == NO) {
    hasFolder = [fileManager createDirectoryAtPath:folder
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:NULL];
  }

  if (!hasFolder) {
    return nil;
  }

  return [folder stringByAppendingPathComponent: file];
}

@end
