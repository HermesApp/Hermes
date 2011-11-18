#import "AppleMediaKeyController.h"
#import "HermesAppDelegate.h"
#import "Keychain.h"
#import "Scrobbler.h"
#import "Growler.h"
#import "PreferencesController.h"

@implementation HermesAppDelegate

@synthesize stations, auth, playback, pandora, window, history;

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

  @try {
    NSString *savedUsername = [self getCachedUsername];
    NSString *savedPassword = [self getCachedPassword];

    [self showLoader];
    [pandora authenticate:savedUsername
                         :savedPassword
                         :nil];
    /* Callback in AuthController will handle everything else */
  } @catch (KeychainException *e) {
    [auth show];
  }

  NSMutableDictionary *app_defaults = [NSMutableDictionary dictionary];
  [app_defaults setObject:@"0" forKey:PLEASE_SCROBBLE];
  [app_defaults setObject:@"1" forKey:PLEASE_GROWL];
  [app_defaults setObject:@"1" forKey:PLEASE_BIND_MEDIA];

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

- (NSString*) getCachedUsername {
  return [[NSUserDefaults standardUserDefaults] stringForKey:USERNAME_KEY];
}

- (NSString*) getCachedPassword {
  return KeychainGetPassword([self getCachedUsername]);
}

- (void)applicationWillResignActive:(NSNotification *)aNotification {
  [stations hideDrawer];
  [playback saveState];
  [history saveSongs];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification {
  if ([pandora authToken] != nil) {
    [stations showDrawer];
  }
}

- (void) applicationWillTerminate: (NSNotification *)aNotification {
  [playback saveState];
  [history saveSongs];
}

- (void) receiveSleepNote: (NSNotification*) note {
  [[playback playing] pause];
}

- (void) handlePandoraError: (NSNotification*) notification {
  NSString *err = [[notification userInfo] objectForKey:@"error"];

  if ([err isEqualToString:@"AUTH_INVALID_USERNAME_PASSWORD"]) {
    [[playback playing] pause];
    [auth authenticationFailed:notification];
  } else if ([err isEqualToString:@"PLAYLIST_END"]) {
    [playback noSongs:notification];
  } else if ([err isEqualToString:@"AUTH_INVALID_TOKEN"]) {
    @try {
      [pandora authenticate:[self getCachedUsername]
                           :[self getCachedPassword]
                           :[[notification userInfo] objectForKey:@"request"]];
    } @catch (KeychainException *e) {
      [[playback playing] pause];
      [auth authenticationFailed:notification];
    }
  } else {
    [self setCurrentView:errorView];
    [errorLabel setStringValue:err];
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
