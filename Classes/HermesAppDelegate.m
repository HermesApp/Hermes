/**
 * @file HermesAppDelegate.m
 * @brief Implementation of the AppDelegate for Hermes
 *
 * Contains startup routines, and other interfaces with the OS
 */

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

@synthesize stations, auth, playback, pandora, window, history, station;

- (bool) isLion {
  static SInt32 MacVersion = 0;

  if (MacVersion == 0) {
    Gestalt(gestaltSystemVersion, &MacVersion);
  }
  return MacVersion >= 0x1070;
}

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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  if ([self isLion]) {
    [window setRestorable:YES];
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
                         :savedPassword
                         :nil];
  }

  NSMutableDictionary *app_defaults = [NSMutableDictionary dictionary];
  [app_defaults setObject:@"0" forKey:PLEASE_SCROBBLE];
  [app_defaults setObject:@"0" forKey:ONLY_SCROBBLE_LIKED];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL_PLAY];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL_NEW];
  [app_defaults setObject:@"1" forKey:PLEASE_BIND_MEDIA];
  [app_defaults setObject:@"0" forKey:PLEASE_CLOSE_DRAWER];
  [app_defaults setObject:QUALITY_MED forKey:DESIRED_QUALITY];
  [app_defaults setObject:[NSNumber numberWithInt:130] forKey:DRAWER_WIDTH];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults registerDefaults:app_defaults];
  if ([defaults boolForKey:PLEASE_SCROBBLE]) {
    [Scrobbler subscribe];
  }
  if ([defaults boolForKey:PLEASE_GROWL]) {
    [Growler subscribe];
  }
  if ([defaults boolForKey:PLEASE_BIND_MEDIA]) {
    [AppleMediaKeyController bindKeys];
  }
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
  menu = [[NSMenu alloc] init];
  NSMenuItem *menuItem;
  Song *song = [[playback playing] playing];
  if (song != nil) {
    [menu addItemWithTitle:@"Now Playing" action:nil keyEquivalent:@""];;
    [menu addItemWithTitle:[NSString stringWithFormat:@"   %@", [song title]]  action:nil keyEquivalent:@""];
    [menu addItemWithTitle:[NSString stringWithFormat:@"   %@", [song artist]]  action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
  }
  if ([[playback playing] isPaused] || song == nil) {
    menuItem = [menu addItemWithTitle:@"Play" action:@selector(playpause:) keyEquivalent:@"p"];
    [menuItem setTarget:playback];
  } else {
    menuItem = [menu addItemWithTitle:@"Pause" action:@selector(playpause:) keyEquivalent:@"p"];
    [menuItem setTarget:playback];
  }
  menuItem = [menu addItemWithTitle:@"Next" action:@selector(next:) keyEquivalent:@"n"];
  [menuItem setTarget:playback];
  if ([[song nrating] intValue] == 1) {
    [menu addItemWithTitle:@"Liked" action:nil keyEquivalent:@""];
  } else {
    menuItem = [menu addItemWithTitle:@"Like" action:@selector(like:) keyEquivalent:@"l"];
    [menuItem setTarget:playback];
  }
  menuItem = [menu addItemWithTitle:@"Dislike" action:@selector(dislike:) keyEquivalent:@"d"];
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

- (void) handlePandoraError: (NSNotification*) notification {
  NSString *err  = [[notification userInfo] objectForKey:@"error"];
  NSNumber *nscode = [[notification userInfo] objectForKey:@"code"];
  NSLogd(@"error received %@", [notification userInfo]);

  if (nscode != nil) {
    int code = [nscode intValue];

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
                               :pass
                               :[[notification userInfo] objectForKey:@"request"]];
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

  [self setCurrentView:errorView];
  [errorLabel setStringValue:err];
  [window orderFront:nil];
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
