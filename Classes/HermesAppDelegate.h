#import "StationsController.h"
#import "AuthController.h"
#import "PlaybackController.h"
#import "Pandora.h"

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
}

@property (readonly) NSWindow *window;
@property (readonly) StationsController *stations;
@property (assign) AuthController *auth;
@property (assign) PlaybackController *playback;
@property (retain) Pandora *pandora;

- (void) closeNewStationSheet;
- (void) showNewStationSheet;
- (void) cacheAuth: (NSString*) username : (NSString*) password;
- (void) setCurrentView: (NSView*) view;
- (void) showLoader;

- (NSString*) getCachedUsername;
- (NSString*) getCachedPassword;

@end
