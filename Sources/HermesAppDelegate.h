#import "Pandora.h"

#define USERNAME_KEY @"pandora.username"

#define DRAWER_STATIONS  0
#define DRAWER_HISTORY   1
#define DRAWER_NONE_HIST 2
#define DRAWER_NONE_STA  3

@class StationsController;
@class AuthController;
@class PlaybackController;
@class HistoryController;
@class StationController;
@class PandoraRequest;
@class Growler;
@class Scrobbler;
@class SPMediaKeyTap;
@class NetworkConnection;
@class PreferencesController;

@interface HermesAppDelegate : NSObject <NSApplicationDelegate> {
  /* Generic loading view */
  IBOutlet NSView *loadingView;
  IBOutlet NSProgressIndicator *loadingIcon;

  /* Pandora error view */
  IBOutlet NSView *errorView;
  IBOutlet NSTextField *errorLabel;
  IBOutlet NSButton *errorButton;
  PandoraRequest *lastRequest;
  Station *lastStationErr;
  NSTimer *autoRetry;

  IBOutlet NSWindow *newStationSheet;
  IBOutlet NSToolbarItem *drawerToggle;
  IBOutlet NSMenu *statusBarMenu;

  /* Status bar menu */
  NSStatusItem *statusItem;
  IBOutlet NSMenuItem *currentSong;
  IBOutlet NSMenuItem *currentArtist;
  IBOutlet NSMenuItem *playbackState;
}

@property (readonly) Pandora *pandora;
@property (readonly) IBOutlet NSWindow *window;
@property (readonly) IBOutlet StationsController *stations;
@property (readonly) IBOutlet HistoryController *history;
@property (readonly) IBOutlet AuthController *auth;
@property (readonly) IBOutlet PlaybackController *playback;
@property (readonly) IBOutlet StationController *station;
@property (readonly) IBOutlet Growler *growler;
@property (readonly) IBOutlet Scrobbler *scrobbler;
@property (readonly) IBOutlet SPMediaKeyTap *mediaKeyTap;
@property (readonly) IBOutlet NetworkConnection *networkManager;
@property (readonly) IBOutlet PreferencesController *preferences;
@property (readonly) BOOL debugMode;

- (void) closeNewStationSheet;
- (void) showNewStationSheet;
- (void) saveUsername: (NSString*) username password: (NSString*) password;
- (void) setCurrentView: (NSView*) view;
- (void) showLoader;
- (NSString*) stateDirectory: (NSString*) file;

- (NSString*) getSavedUsername;
- (NSString*) getSavedPassword;

- (void) tryRetry;
- (void) handleDrawer;

- (IBAction) changelog:(id)sender;
- (IBAction) hermesOnGitHub:(id)sender;
- (IBAction) reportAnIssue:(id)sender;
- (IBAction) hermesHomepage:(id)sender;
- (IBAction) retry:(id)sender;
- (IBAction) toggleDrawerContent:(id)sender;
- (IBAction) toggleDrawerVisible:(id)sender;
- (IBAction) showStationsDrawer:(id)sender;
- (IBAction) showHistoryDrawer:(id)sender;
- (IBAction) activate:(id)sender;
- (IBAction) updateStatusBarIcon:(id)sender;
- (IBAction) updateStatusBarIconImage:(id)sender;
- (IBAction) updateStatusBarIconValue:(id)sender;
- (IBAction) updateAlwaysOnTop:(id)sender;

/**
 * Log message to Hermes-specific logging facility.
 *
 * @param message the NSString to log
 */
- (void)logMessage:(NSString *)message;

@end
