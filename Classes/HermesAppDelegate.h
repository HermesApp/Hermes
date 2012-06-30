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

@interface HermesAppDelegate : NSObject <NSApplicationDelegate> {
  Pandora *pandora;

  /* Generic loading view */
  IBOutlet NSView *loadingView;
  IBOutlet NSProgressIndicator *loadingIcon;

  /* Pandora error view */
  IBOutlet NSView *errorView;
  IBOutlet NSTextField *errorLabel;
  IBOutlet NSButton *errorButton;
  PandoraRequest *lastRequest;
  Station *lastStationErr;

  IBOutlet NSWindow *window;
  IBOutlet NSWindow *newStationSheet;
  IBOutlet NSToolbarItem *drawerToggle;

  /* Objects */
  IBOutlet StationsController *stations;
  IBOutlet AuthController *auth;
  IBOutlet PlaybackController *playback;
  IBOutlet HistoryController *history;
  IBOutlet StationController *station;
  IBOutlet Growler *growler;
  IBOutlet Scrobbler *scrobbler;
  IBOutlet SPMediaKeyTap *mediaKeyTap;
}

@property (readonly) NSWindow *window;
@property (readonly) StationsController *stations;
@property (readonly) HistoryController *history;
@property (retain) AuthController *auth;
@property (retain) PlaybackController *playback;
@property (retain) StationController *station;
@property (retain) Pandora *pandora;
@property (retain) Growler *growler;
@property (retain) Scrobbler *scrobbler;
@property (retain) SPMediaKeyTap *mediaKeyTap;

- (void) closeNewStationSheet;
- (void) showNewStationSheet;
- (void) cacheAuth: (NSString*) username : (NSString*) password;
- (void) setCurrentView: (NSView*) view;
- (void) showLoader;
- (NSString*) stateDirectory: (NSString*) file;

- (NSString*) getCachedUsername;
- (NSString*) getCachedPassword;

- (void) tryRetry;
- (void) handleDrawer;

- (IBAction) donate:(id)sender;
- (IBAction) retry:(id)sender;
- (IBAction) toggleDrawerContent:(id)sender;
- (IBAction) toggleDrawerVisible:(id)sender;
- (IBAction) showStationsDrawer:(id)sender;
- (IBAction) showHistoryDrawer:(id)sender;

@end
