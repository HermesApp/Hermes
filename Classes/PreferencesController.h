/**
 * @file PreferencesController.h
 * @brief Headers for the PreferencesController class and preferences keys
 *        which are set from it
 */

#define PLEASE_BIND_MEDIA     @"hermes.please-bind-media"
#define PLEASE_SCROBBLE       @"hermes.please-scrobble"
#define PLEASE_SCROBBLE_LIKES @"hermes.please-scrobble-likes"
#define ONLY_SCROBBLE_LIKED   @"hermes.only-scrobble-liked"
#define PLEASE_GROWL          @"hermes.please-growl"
#define PLEASE_GROWL_NEW      @"hermes.please-growl-new"
#define PLEASE_GROWL_PLAY     @"hermes.please-growl-play"
#define PLEASE_CLOSE_DRAWER   @"hermes.please-close-drawer"
#define DRAWER_WIDTH          @"hermes.drawer-width"
#define DESIRED_QUALITY       @"hermes.audio-quality"
#define LAST_PREF_PANE        @"hermes.last-pref-pane"

#define QUALITY_HIGH @"high"
#define QUALITY_LOW  @"low"
#define QUALITY_MED  @"medium"

@interface PreferencesController : NSObject <NSWindowDelegate> {
  /* General */
  IBOutlet NSButton *scrobble;
  IBOutlet NSButton *scrobbleLikes;
  IBOutlet NSButton *scrobbleOnlyLiked;
  IBOutlet NSButton *bindMedia;
  IBOutlet NSButton *growl;
  IBOutlet NSButton *growlPlayPause;
  IBOutlet NSButton *growlNewSongs;

  /* Playback */
  IBOutlet NSButtonCell *highQuality;
  IBOutlet NSButtonCell *mediumQuality;
  IBOutlet NSButtonCell *lowQuality;

  IBOutlet NSToolbar *toolbar;
  IBOutlet NSView *general;
  IBOutlet NSView *playback;
  IBOutlet NSWindow *window;
}

/* General */
- (IBAction) changeScrobbleTo: (id) sender;
- (IBAction) changeScrobbleLikesTo: (id) sender;
- (IBAction) changeScrobbleOnlyLikedTo: (id) sender;
- (IBAction) changeBindMediaTo: (id) sender;
- (IBAction) changeGrowlTo: (id) sender;
- (IBAction) changeGrowlPlayPauseTo: (id) sender;
- (IBAction) changeGrowlNewSongTo: (id) sender;

/* Playback */
- (IBAction) changeQualityToLow:(id)sender;
- (IBAction) changeQualityToMedium:(id)sender;
- (IBAction) changeQualityToHigh:(id)sender;

- (IBAction) showGeneral: (id) sender;
- (IBAction) showPlayback: (id) sender;

@end
