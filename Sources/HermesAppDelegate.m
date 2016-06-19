/**
 * @file HermesAppDelegate.m
 * @brief Implementation of the AppDelegate for Hermes
 *
 * Contains startup routines, and other interfaces with the OS
 */

#import <SPMediaKeyTap/SPMediaKeyTap.h>

#import "AuthController.h"
#import "Integration/Growler.h"
#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "Integration/Keychain.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "Integration/Scrobbler.h"
#import "StationController.h"
#import "StationsController.h"
#import "Notifications.h"

// strftime_l()
#include <time.h>
#include <xlocale.h>

#define HERMES_LOG_DIRECTORY_PATH @"~/Library/Logs/Hermes/"
#define DEBUG_MODE_TITLE_PREFIX @"🐞 "

@interface HermesAppDelegate ()

@property (readonly) NSString *hermesLogFile;
@property (readonly, nonatomic) FILE *hermesLogFileHandle;

@end

@implementation HermesAppDelegate

@synthesize stations, auth, playback, pandora, window, history, station,
            growler, scrobbler, mediaKeyTap, networkManager, preferences;

#pragma mark - NSObject

- (id) init {
  if ((self = [super init])) {
    pandora = [[Pandora alloc] init];
    _debugMode = NO;
  }
  return self;
}

- (void)dealloc {
  if (self.hermesLogFileHandle) {
    fclose(self.hermesLogFileHandle);
  }
}

#pragma mark -

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                    hasVisibleWindows:(BOOL)flag {
  if (!flag) {
    [window makeKeyAndOrderFront:nil];
  }

  return YES;
}

- (void) closeNewStationSheet {
  [window endSheet:newStationSheet];
}

- (void) showNewStationSheet {
  [window beginSheet:newStationSheet completionHandler:nil];
}

- (void) showLoader {
  [self setCurrentView:loadingView];
  [loadingIcon startAnimation:nil];
}

- (void) saveUsername: (NSString*) username password: (NSString*) password {
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
    [superview replaceSubview:prev_view with:view];
    // FIXME: This otherwise looks nicer but it causes the toolbar to flash.
    // [[superview animator] replaceSubview:prev_view with:view];
  } else {
    [superview addSubview:view];
  }

  NSRect frame = [view frame];
  NSRect superFrame = [superview frame];
  frame.size.width = superFrame.size.width;
  frame.size.height = superFrame.size.height;
  [view setFrame:frame];

  [self updateWindowTitle];
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
  NSUInteger flags = ([NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
  BOOL isOptionPressed = (flags == NSAlternateKeyMask);
  
  if (isOptionPressed && [self configureLogFile]) {
    _debugMode = YES;
    HMSLog("Starting in debug mode. Log file: %@", self.hermesLogFile);
    [self updateWindowTitle];
  }
  
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
            name:PandoraDidErrorNotification
          object:nil];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(handleStreamError:)
            name:ASStreamError
          object:nil];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(handlePandoraLoggedOut:)
            name:PandoraDidLogOutNotification
          object:nil];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(songPlayed:)
            name:StationDidPlaySongNotification
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

  NSString *savedUsername = [self getSavedUsername];
  NSString *savedPassword = [self getSavedPassword];
  if (savedPassword == nil || [savedPassword isEqualToString:@""] ||
      savedUsername == nil || [savedUsername isEqualToString:@""]) {
    [auth show];
  } else {
    [self showLoader];
    [pandora authenticate:[self getSavedUsername]
                 password:[self getSavedPassword]
                  request:nil];
  }

  NSDictionary *app_defaults = @{
    PLEASE_SCROBBLE:            @"0",
    ONLY_SCROBBLE_LIKED:        @"0",
    PLEASE_GROWL:               @"1",
    PLEASE_GROWL_PLAY:          @"0",
    PLEASE_GROWL_NEW:           @"1",
    PLEASE_BIND_MEDIA:          @"1",
    PLEASE_CLOSE_DRAWER:        @"0",
    ENABLED_PROXY:              @PROXY_SYSTEM,
    PROXY_AUDIO:                @"0",
    DESIRED_QUALITY:            @QUALITY_MED,
    OPEN_DRAWER:                @DRAWER_STATIONS,
    HIST_DRAWER_WIDTH:          @150,
    DRAWER_WIDTH:               @130,
    GROWL_TYPE:                 @GROWL_TYPE_OSX,
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
  menuItem = [menu addItemWithTitle:@"Like"
                             action:@selector(like:)
                      keyEquivalent:@"l"];
  [menuItem setTarget:playback];
  if ([[song nrating] intValue] == 1) {
    menuItem.state = NSOnState;
  }
  menuItem = [menu addItemWithTitle:@"Dislike"
                             action:@selector(dislike:)
                      keyEquivalent:@"d"];
  [menuItem setTarget:playback];
  return menu;
}

- (NSString*) getSavedUsername {
  return [[NSUserDefaults standardUserDefaults] stringForKey:USERNAME_KEY];
}

- (NSString*) getSavedPassword {
  return KeychainGetPassword([self getSavedUsername]);
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
  NSString *other = [Pandora stringForErrorCode:code];
  if (other != nil) {
    err = other;
  }

  if (nscode != nil) {
    [errorButton setHidden:TRUE];

    switch (code) {
      case INVALID_SYNC_TIME:
      case INVALID_AUTH_TOKEN: {
        NSString *user = [self getSavedUsername];
        NSString *pass = [self getSavedPassword];
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

  // From the unofficial Pandora API documentation ( http://6xq.net/playground/pandora-apidoc/json/errorcodes/ ):
  // code 0 == INTERNAL, "It can denote that your account has been temporarily blocked due to having too frequent station.getPlaylist calls."
  // code 1039 == PLAYLIST_EXCEEDED, "Returned on excessive calls to station.getPlaylist. Error self clears (probably 1 hour)."
  if (code != 0 && code != 1039) {
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
  [station editStation:nil];

  /* Remove our credentials */
  [self saveUsername:@"" password:@""];
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

- (IBAction)showMainWindow:(id)sender {
    [self activate:nil];
}

- (IBAction)changelog:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/HermesApp/Hermes/blob/master/CHANGELOG.md"]];
}

- (IBAction) hermesOnGitHub:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/HermesApp/Hermes"]];
}

- (IBAction) reportAnIssue:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/HermesApp/Hermes/issues"]];
}

- (IBAction)hermesHomepage:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://hermesapp.org/"]];
}

- (void) historyShow {
  [history showDrawer];
  [drawerToggle setImage:[NSImage imageNamed:@"radio"]];
  [drawerToggle setToolTip: @"Show station list"];
  drawerToggle.paletteLabel = drawerToggle.label = @"Stations";
}

- (void) stationsShow {
  [stations showDrawer];
  [drawerToggle setImage:[NSImage imageNamed:@"history"]];
  [drawerToggle setToolTip: @"Show song history"];
  drawerToggle.paletteLabel = drawerToggle.label = @"History";
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
      break;
    case DRAWER_STATIONS:
      [stations hideDrawer];
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
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

  statusItemImageName = @"";
  [self updateStatusBarIconImage:sender];
}

- (IBAction) updateStatusBarIconImage:(id)sender {
  if (!PREF_KEY_BOOL(STATUS_BAR_ICON))
    return;

  NSString *imageName = nil;
  if (PREF_KEY_BOOL(STATUS_BAR_ICON_BNW))
    imageName = (playback.playing.isPlaying) ? @"Pandora-Menu-Dark-Play" : @"Pandora-Menu-Dark-Pause";

  if (imageName == statusItemImageName)
    return;

  NSImage *icon;
  if (imageName == nil) {
    icon = [[NSApp applicationIconImage] copy];
  } else {
    icon = [NSImage imageNamed:imageName];
    [icon setTemplate:YES];
  }

  NSSize size = {.width = 18, .height = 18};
  [icon setSize:size];

  [statusItem setImage:icon];
  statusItemImageName = imageName;
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

- (void)playbackStateChanged:(NSNotification*) not {
  AudioStreamer *stream = [not object];
  if ([stream isPlaying]) {
    [playbackState setTitle:@"Pause"];
  } else {
    [playbackState setTitle:@"Play"];
  }
  [self updateWindowTitle];
  [self updateStatusBarIconImage:nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
  if (![[self pandora] isAuthenticated]) {
    return NO;
  }
  return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  SEL action = [menuItem action];

  if (action == @selector(showHistoryDrawer:) || action == @selector(showStationsDrawer:) || action == @selector(toggleDrawerVisible:)) {
    if (!self.pandora.isAuthenticated)
      return NO;

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

- (void)updateWindowTitle {
  NSString *debugTitlePrefix = self.debugMode ? DEBUG_MODE_TITLE_PREFIX : @"";
  if (playback.playing != nil) {
    [window setTitle:[NSString stringWithFormat:@"%@%@", debugTitlePrefix, playback.playing.name]];
  } else {
    [window setTitle:[NSString stringWithFormat:@"%@Hermes", debugTitlePrefix]];
  }
}

#pragma mark - Logging facility

- (BOOL)configureLogFile {
  NSString *hermesStandardizedLogPath = [HERMES_LOG_DIRECTORY_PATH stringByStandardizingPath];
  NSError *error = nil;
  BOOL logPathCreated = [[NSFileManager defaultManager] createDirectoryAtPath:hermesStandardizedLogPath
                                                  withIntermediateDirectories:YES
                                                                   attributes:nil
                                                                        error:&error];
  if (!logPathCreated) {
    NSLog(@"Hermes: failed to create logging directory \"%@\". Logging is disabled.", hermesStandardizedLogPath);
    return NO;
  }
  
#define CURRENTTIMEBYTES 50
  // Use unlocalized, fixed-format date functions as prescribed in
  // "Data Formatting Guide" section "Consider Unix Functions for Fixed-Format, Unlocalized Dates"
  // https://developer.apple.com/library/ios/documentation/cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html
  time_t now;
  struct tm *localNow;
  char currentDateTime[CURRENTTIMEBYTES];
  
  time(&now);
  localNow = localtime(&now);
  strftime_l(currentDateTime, CURRENTTIMEBYTES, "%Y-%m-%d_%H:%M:%S_%z", localNow, NULL);
  
  _hermesLogFile = [[NSString stringWithFormat:@"%@/HermesLog_%s.log", HERMES_LOG_DIRECTORY_PATH, currentDateTime] stringByStandardizingPath];
  static dispatch_once_t onceTokenForOpeningLogFile = 0;
  dispatch_once(&onceTokenForOpeningLogFile, ^{
    _hermesLogFileHandle = fopen([self.hermesLogFile cStringUsingEncoding:NSUTF8StringEncoding], "a");
    setvbuf(self.hermesLogFileHandle, NULL, _IOLBF, 0);
  });
  return YES;
}

- (void)logMessage:(NSString *)message {
#if DEBUG
    // Keep old behavior of DEBUG mode.
    NSLog(@"%@", message);
#endif
    
    if (self.debugMode) {
      if (self.hermesLogFileHandle) {
        fprintf(self.hermesLogFileHandle, "%s\n", [message cStringUsingEncoding:NSUTF8StringEncoding]);
      } else {
#ifndef DEBUG
        // Fall back on NSLog if the log file did not open properly.
        NSLog(@"%@", message);
#endif
      }
    }
}

#pragma mark - QLPreviewPanelController

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
