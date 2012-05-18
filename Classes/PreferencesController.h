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
#define DESIRED_QUALITY       @"hermes.audio-quality"

#define QUALITY_HIGH @"high"
#define QUALITY_LOW  @"low"
#define QUALITY_MED  @"medium"

@interface PreferencesController : NSObject <NSWindowDelegate> {
  /* General */
  NSButton *scrobble;
  NSButton *scrobbleLikes;
  NSButton *scrobbleOnlyLiked;
  NSButton *bindMedia;
  NSButton *growl;
  NSButton *growlPlayPause;
  NSButton *growlNewSongs;

  /* Playback */
  NSButtonCell *highQuality;
  NSButtonCell *mediumQuality;
  NSButtonCell *lowQuality;

  NSToolbar *toolbar;
  NSView *general;
  NSView *playback;
  NSWindow *window;
}

@property (nonatomic, retain) IBOutlet NSButton *scrobble;
@property (nonatomic, retain) IBOutlet NSButton *scrobbleLikes;
@property (nonatomic, retain) IBOutlet NSButton *scrobbleOnlyLiked;
@property (nonatomic, retain) IBOutlet NSButton *bindMedia;
@property (nonatomic, retain) IBOutlet NSButton *growl;
@property (nonatomic, retain) IBOutlet NSButton *growlPlayPause;
@property (nonatomic, retain) IBOutlet NSButton *growlNewSongs;
@property (nonatomic, retain) IBOutlet NSToolbar *toolbar;
@property (nonatomic, retain) IBOutlet NSView *general;
@property (nonatomic, retain) IBOutlet NSView *playback;
@property (nonatomic, retain) IBOutlet NSWindow *window;
@property (nonatomic, retain) IBOutlet NSButtonCell *highQuality;
@property (nonatomic, retain) IBOutlet NSButtonCell *mediumQuality;
@property (nonatomic, retain) IBOutlet NSButtonCell *lowQuality;

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
