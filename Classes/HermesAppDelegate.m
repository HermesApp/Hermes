#import "AppleMediaKeyController.h"
#import "HermesAppDelegate.h"
#import "Keychain.h"
#import "Scrobbler.h"
#import "PreferencesController.h"

@implementation HermesAppDelegate

@synthesize stations, auth, playback, pandora, window;

- (id) init {
  pandora = [[Pandora alloc] init];
  return self;
}

- (void) dealloc {
  [pandora release];
  [super dealloc];
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
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(handlePandoraError:)
    name:@"hermes.pandora-error"
    object:[[NSApp delegate] pandora]];

  // See http://developer.apple.com/mac/library/qa/qa2004/qa1340.html
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
      selector: @selector(receiveSleepNote:)
      name: NSWorkspaceWillSleepNotification object: NULL];

  @try {
    NSString *savedUsername = [self getCachedUsername];
    NSString *savedPassword = [self getCachedPassword];

    [self showLoader];
    [pandora authenticate: savedUsername : savedPassword];
    /* Callback in AuthController will handle everything else */
  } @catch (KeychainException *e) {
    [auth show];
  }

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:PLEASE_SCROBBLE]) {
    [Scrobbler subscribe];
  }

  if ([defaults boolForKey:PLEASE_BIND_MEDIA]) {
    [AppleMediaKeyController bindKeys];
  }
}

- (NSString*) getCachedUsername {
  return [[NSUserDefaults standardUserDefaults] stringForKey:USERNAME_KEY];
}

- (NSString*) getCachedPassword {
  return KeychainGetPassword([self getCachedUsername]);
}

- (void)applicationWillResignActive:(NSNotification *)aNotification {
  [stations hideDrawer];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification {
  if ([pandora authToken] != nil) {
    [stations showDrawer];
  }
}

- (void) receiveSleepNote: (NSNotification*) note {
  [[playback playing] pause];
}

- (void) handlePandoraError: (NSNotification*) notification {
  NSString *err = [[notification userInfo] objectForKey:@"error"];

  if ([err isEqualToString:@"AUTH_INVALID_USERNAME_PASSWORD"]) {
    [auth authenticationFailed:notification];
  } else if ([err isEqualToString:@"PLAYLIST_END"]) {
    [playback noSongs:notification];
  } else {
    [self setCurrentView:errorView];
    [errorLabel setStringValue:err];
  }
}

@end
