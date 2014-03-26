/**
 * @file HermesAppDelegate.m
 * @brief Implementation of the AppDelegate for Hermes
 *
 * Contains startup routines, and other interfaces with the OS
 */

#import <SPMediaKeyTap/SPMediaKeyTap.h>

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
            growler, scrobbler, mediaKeyTap, networkManager, preferences;

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
    NSView *prev_view = [superview subviews][0];
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
  NSDictionary *map = @{
    @"hermes.please-bind-media":        PLEASE_BIND_MEDIA,
    @"hermes.please-scrobble":          PLEASE_SCROBBLE,
    @"hermes.please-scrobble-likes":    PLEASE_SCROBBLE_LIKES,
    @"hermes.only-scrobble-likes":      ONLY_SCROBBLE_LIKED,
    @"hermes.please-growl":             PLEASE_GROWL,
    @"hermes.please-growl-new":         PLEASE_GROWL_NEW,
    @"hermes.please-growl-play":        PLEASE_GROWL_PLAY,
    @"hermes.please-close-drawer":      PLEASE_CLOSE_DRAWER,
    @"hermes.drawer-width":             DRAWER_WIDTH,
    @"hermes.audio-quality":            DESIRED_QUALITY,
    @"hermes.last-pref-pane":           LAST_PREF_PANE
  };

  NSDictionary *d = [defaults dictionaryRepresentation];

  for (NSString *key in d) {
    NSString *newKey = map[key];
    if (newKey == nil) continue;
    [defaults setObject:[defaults objectForKey:key]
                 forKey:map[key]];
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

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Must do this before the app is activated, or the menu bar doesn't draw.
  // <http://stackoverflow.com/questions/7596643/>
  [self updateStatusBarIcon:nil];
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
            name:ASStreamError
          object:nil];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(handlePandoraLoggedOut:)
            name:@"hermes.logged-out"
          object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(songPlayed:)
            name:@"song.playing"
          object:nil];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(playbackStateChanged:)
            name:ASStatusChangedNotification
          object:nil];

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

  NSDictionary *app_defaults = @{
    PLEASE_SCROBBLE:            @"0",
    ONLY_SCROBBLE_LIKED:        @"0",
    PLEASE_GROWL:               @"1",
    PLEASE_GROWL_PLAY:          @"1",
    PLEASE_GROWL_NEW:           @"1",
    PLEASE_BIND_MEDIA:          @"1",
    PLEASE_CLOSE_DRAWER:        @"0",
    ENABLED_PROXY:              @PROXY_SYSTEM,
    PROXY_AUDIO:                @"0",
    DESIRED_QUALITY:            @QUALITY_MED,
    OPEN_DRAWER:                @DRAWER_STATIONS,
    HIST_DRAWER_WIDTH:          @150,
    DRAWER_WIDTH:               @130,
    GROWL_TYPE:                 @GROWL_TYPE_GROWL,
    kMediaKeyUsingBundleIdentifiersDefaultsKey:
        [SPMediaKeyTap defaultMediaKeyUserBundleIdentifiers]
  };

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults registerDefaults:app_defaults];
  [self migrateDefaults:defaults];
  [playback prepareFirst];

#ifndef DEBUG
  mediaKeyTap = [[SPMediaKeyTap alloc] initWithDelegate:playback];
  if (PREF_KEY_BOOL(PLEASE_BIND_MEDIA)) {
    [mediaKeyTap startWatchingMediaKeys];
  }
#endif

  [self updateAlwaysOnTop:nil];
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
  NSMenu *menu = [[NSMenu alloc] init];
  NSMenuItem *menuItem;
  Song *song = [[playback playing] playingSong];
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
  NSString *err      = info[@"error"];
  NSNumber *nscode   = info[@"code"];
  NSLogd(@"error received %@", info);
  /* If this is a generic error (like a network error) it's possible to retry.
     Otherewise if it's a Pandora error (with a code listed) there's likely
     nothing we can do about it */
  [errorButton setHidden:FALSE];
  lastRequest = nil;
  int code = [nscode intValue];
  NSString *other = [Pandora errorString:code];
  if (other != nil) {
    err = other;
  }

  if (nscode != nil) {
    [errorButton setHidden:TRUE];

    switch (code) {
      case INVALID_SYNC_TIME:
      case INVALID_AUTH_TOKEN: {
        NSString *user = [self getCachedUsername];
        NSString *pass = [self getCachedPassword];
        if (user == nil || pass == nil) {
          [[playback playing] pause];
          [auth authenticationFailed:notification error:err];
        } else {
          [pandora logoutNoNotify];
          [pandora authenticate:user
                       password:pass
                        request:info[@"request"]];
        }
        return;
      }

      /* Oddly enough, the same error code is given our for invalid login
         information as is for invalid partner login information... */
      case INVALID_PARTNER_LOGIN:
      case INVALID_USERNAME:
      case INVALID_PASSWORD:
        [[playback playing] pause];
        [auth authenticationFailed:notification error:err];
        return;

      case NO_SEEDS_LEFT:
        [station seedFailedDeletion:notification];
        return;

      default:
        break;
    }
  }

  lastRequest = [notification userInfo][@"request"];
  [self setCurrentView:errorView];
  [errorLabel setStringValue:err];
  [window orderFront:nil];
  [autoRetry invalidate];

  // code 0 == internal error, and if we're getting a fragment then this means
  // that we shouldn't retry because it's only going to keep failing
  if (code != 0 &&
      ![[lastRequest method] isEqual:@"station.getFragment"] &&
      code != 1039) // rate limit
  {
      autoRetry = [NSTimer scheduledTimerWithTimeInterval:20
                                                   target:self
                                                 selector:@selector(retry:)
                                                 userInfo:nil
                                                  repeats:NO];
  }
}

- (void) retry:(id)sender {
  [autoRetry invalidate];
  autoRetry = nil;
  if (lastRequest != nil) {
    [pandora sendRequest:lastRequest];
    lastRequest = nil;
    if ([playback playing] && ([[playback playing] isPlaying] ||
                               [[playback playing] isPaused])) {
      [playback show];
    } else {
      [self showLoader];
    }
  } else if (lastStationErr != nil) {
    [lastStationErr retry];
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
  [stations hideDrawer];
  [history hideDrawer];

  /* Remove our credentials */
  [self cacheAuth:@"" :@""];
  [auth show];
}

+ (BOOL)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))done {
  [PlaybackController setPlayOnStart:NO];
  done(nil, nil);
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

- (IBAction) donate:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=58H9GQKN28GNL"]];
}

- (void) historyShow {
  [history showDrawer];
  [drawerToggle setImage:[NSImage imageNamed:@"radio"]];
  [drawerToggle setToolTip: @"Show station list"];
}

- (void) stationsShow {
  [stations showDrawer];
  [drawerToggle setImage:[NSImage imageNamed:@"history"]];
  [drawerToggle setToolTip: @"Show song history"];
}

- (IBAction) showHistoryDrawer:(id)sender {
  if ([PREF_KEY_VALUE(OPEN_DRAWER) intValue] == DRAWER_HISTORY) {
    [history focus];
    return;
  }
  [self historyShow];
  [stations hideDrawer];
  PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_HISTORY);
}

- (IBAction) showStationsDrawer:(id)sender {
  if ([PREF_KEY_VALUE(OPEN_DRAWER) intValue] == DRAWER_STATIONS) {
    [stations focus];
    return;
  }
  [history hideDrawer];
  [self stationsShow];
  PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_STATIONS);
}

- (void) handleDrawer {
  switch ([PREF_KEY_VALUE(OPEN_DRAWER) intValue]) {
    case DRAWER_NONE_HIST:
    case DRAWER_NONE_STA:
      break;
    case DRAWER_HISTORY:
      [self historyShow];
      break;
    case DRAWER_STATIONS:
      [self stationsShow];
      break;
  }
}

- (IBAction) toggleDrawerContent:(id)sender {
  switch ([PREF_KEY_VALUE(OPEN_DRAWER) intValue]) {
    case DRAWER_NONE_HIST:
      [self historyShow];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_HISTORY);
      break;
    case DRAWER_NONE_STA:
      [self stationsShow];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_STATIONS);
      break;
    case DRAWER_HISTORY:
      [self stationsShow];
      [history hideDrawer];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_STATIONS);
      break;
    case DRAWER_STATIONS:
      [stations hideDrawer];
      [self historyShow];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_HISTORY);
      break;
  }
}

- (IBAction) toggleDrawerVisible:(id)sender {
  switch ([PREF_KEY_VALUE(OPEN_DRAWER) intValue]) {
    case DRAWER_NONE_HIST:
      [self historyShow];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_HISTORY);
      break;
    case DRAWER_NONE_STA:
      [self stationsShow];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_STATIONS);
      break;
    case DRAWER_HISTORY:
      [history hideDrawer];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_NONE_HIST);
      break;
    case DRAWER_STATIONS:
      [stations hideDrawer];
      PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_NONE_STA);
      break;
  }
}

- (IBAction) updateStatusBarIcon:(id)sender {
  /* Transform the application appropriately */
  ProcessSerialNumber psn = { 0, kCurrentProcess };
  if (!PREF_KEY_BOOL(STATUS_BAR_ICON)) {
    [window setCanHide:YES];
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    statusItem = nil;

    if (sender != nil) {
      /* If we're not executing at process launch, then the menu bar will be shown
         but be unusable until we switch to another application and back to Hermes */
      [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock"
                                                           options:NSWorkspaceLaunchDefault
                                    additionalEventParamDescriptor:nil
                                                  launchIdentifier:nil];
      [NSApp activateIgnoringOtherApps:YES];
    }
    return;
  }

  if (sender != nil) {
    /* If we're not executing at process launch, then the menu bar will remain visible
       but unusable; hide/show Hermes to fix it, but stop the window from hiding with it */
    [window setCanHide:NO];

    /* Causes underlying window to activate briefly, but no other solution I could find */
    [NSApp hide:nil];
    dispatch_async(dispatch_get_current_queue(), ^{
      TransformProcessType(&psn, kProcessTransformToUIElementApplication);
      [NSApp activateIgnoringOtherApps:YES];
      [[NSApp mainWindow] makeKeyAndOrderFront:nil]; // restores mouse cursor
    });
  }

  /* If we have a status menu item, then set it here */
  statusItem = [[NSStatusBar systemStatusBar]
                    statusItemWithLength:NSVariableStatusItemLength];
  [statusItem setMenu:statusBarMenu];
  [statusItem setHighlightMode:YES];

  [self updateStatusBarIconColor:sender];
}

- (IBAction) updateStatusBarIconColor:(id)sender {
    /* If we have a status menu item, then set it here */

    NSImage *icon = [NSApp applicationIconImage];
    if (PREF_KEY_BOOL(STATUS_BAR_ICON_BNW)) {
      icon = [NSImage imageNamed:@"pandora-black"];
    }

    NSSize size = {.width = 18, .height = 18};
    [icon setSize:size];
    [statusItem setImage:icon];
}

- (IBAction) updateAlwaysOnTop:(id)sender {
  if (PREF_KEY_BOOL(ALWAYS_ON_TOP)) {
    [[self window] setLevel:NSFloatingWindowLevel];
  } else {
    [[self window] setLevel:NSNormalWindowLevel];
  }
}

- (IBAction) activate:(id)sender {
  [NSApp activateIgnoringOtherApps:YES];
  [window makeKeyAndOrderFront:sender];
}

- (void) songPlayed:(NSNotification*) not {
  Station *s = [not object];
  Song *playing = [s playingSong];
  if (playing != nil) {
    [currentSong setTitle:[playing title]];
    [currentArtist setTitle:[playing artist]];
  } else {
    [currentSong setTitle:@"(song)"];
    [currentArtist setTitle:@"(artist)"];
  }
}

- (void) playbackStateChanged:(NSNotification*) not {
  AudioStreamer *stream = [not object];
  if ([stream isPlaying]) {
    [window setTitle:playback.playing.name];
    [playbackState setTitle:@"Pause"];
  } else {
    [playbackState setTitle:@"Play"];
  }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  SEL action = [menuItem action];

  if (action == @selector(showHistoryDrawer:) || action == @selector(showStationsDrawer:) || action == @selector(toggleDrawerVisible:)) {
    NSInteger openDrawer = [PREF_KEY_VALUE(OPEN_DRAWER) integerValue];
    NSCellStateValue state = NSOffState;
    if (action == @selector(showHistoryDrawer:)) {
      if (openDrawer == DRAWER_NONE_HIST)
        state = NSMixedState;
      else if (openDrawer == DRAWER_HISTORY)
        state = NSOnState;
    } else if (action == @selector(showStationsDrawer:)) {
      if (openDrawer == DRAWER_NONE_STA)
        state = NSMixedState;
      else if (openDrawer == DRAWER_STATIONS)
        state = NSOnState;
    } else {
      if (openDrawer == DRAWER_HISTORY || openDrawer == DRAWER_STATIONS)
        [menuItem setTitle:@"Hide Drawer"];
      else
        [menuItem setTitle:@"Show Drawer"];
    }
    [menuItem setState:state];
  }

  return YES;
}

#pragma mark QLPreviewPanelController

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
  return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
  panel.dataSource = playback;
  panel.delegate = playback;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
  panel.dataSource = nil;
  panel.delegate = nil;
}

@end
