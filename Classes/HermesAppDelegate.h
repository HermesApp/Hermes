#import "StationsController.h"
#import "AuthController.h"
#import "PlaybackController.h"
#import "HistoryController.h"
#import "Pandora.h"

#define USERNAME_KEY @"pandora.username"

@interface HermesAppDelegate : NSObject <NSApplicationDelegate> {

  Pandora *pandora;

  /* Generic loading view */
  IBOutlet NSView *loadingView;
  IBOutlet NSProgressIndicator *loadingIcon;

  /* Pandora error view */
  IBOutlet NSView *errorView;
  IBOutlet NSTextField *errorLabel;

  IBOutlet NSWindow *window;
  IBOutlet NSWindow *newStationSheet;

  IBOutlet StationsController *stations;
  IBOutlet AuthController *auth;
  IBOutlet PlaybackController *playback;

  IBOutlet HistoryController *history;
}

@property (readonly) NSWindow *window;
@property (readonly) StationsController *stations;
@property (readonly) HistoryController *history;
@property (retain) AuthController *auth;
@property (retain) PlaybackController *playback;
@property (retain) Pandora *pandora;

- (void) closeNewStationSheet;
- (void) showNewStationSheet;
- (void) cacheAuth: (NSString*) username : (NSString*) password;
- (void) setCurrentView: (NSView*) view;
- (void) showLoader;
- (NSString*) stateDirectory: (NSString*) file;

- (NSString*) getCachedUsername;
- (NSString*) getCachedPassword;

@end
