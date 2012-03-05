/**
 * @file PreferencesController.h
 * @brief Headers for the PreferencesController class and preferences keys
 *        which are set from it
 */

#define PLEASE_BIND_MEDIA @"hermes.please-bind-media"
#define PLEASE_SCROBBLE   @"hermes.please-scrobble"
#define PLEASE_GROWL      @"hermes.please-growl"
#define PLEASE_GROWL_NEW  @"hermes.please-growl"
#define PLEASE_GROWL_PLAY @"hermes.please-growl"

@interface PreferencesController : NSObject <NSWindowDelegate> {
  NSButton *scrobble;
  NSButton *bindMedia;
  NSButton *growl;
  NSButton *growlPlayPause;
  NSButton *growlNewSongs;
}

@property (nonatomic, retain) IBOutlet NSButton *scrobble;
@property (nonatomic, retain) IBOutlet NSButton *bindMedia;
@property (nonatomic, retain) IBOutlet NSButton *growl;
@property (nonatomic, retain) IBOutlet NSButton *growlPlayPause;
@property (nonatomic, retain) IBOutlet NSButton *growlNewSongs;

- (IBAction) changeScrobbleTo: (id) sender;
- (IBAction) changeBindMediaTo: (id) sender;
- (IBAction) changeGrowlTo: (id) sender;
- (IBAction) changeGrowlPlayPauseTo: (id) sender;
- (IBAction) changeGrowlNewSongTo: (id) sender;

@end
