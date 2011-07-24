#define PLEASE_BIND_MEDIA @"hermes.please-bind-media"
#define PLEASE_SCROBBLE @"hermes.please-scrobble"

@interface PreferencesController : NSObject <NSWindowDelegate> {
  NSButton *scrobble;
  NSButton *bindMedia;
}

@property (nonatomic, retain) IBOutlet NSButton *scrobble;
@property (nonatomic, retain) IBOutlet NSButton *bindMedia;

- (IBAction) changeScrobbleTo: (id) sender;
- (IBAction) changeBindMediaTo: (id) sender;

@end
