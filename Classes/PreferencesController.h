#define PLEASE_BIND_MEDIA @"hermes.please-bind-media"
#define PLEASE_SCROBBLE @"hermes.please-scrobble"
#define PLEASE_GROWL @"hermes.please-growl"

@interface PreferencesController : NSObject <NSWindowDelegate> {
  NSButton *scrobble;
  NSButton *bindMedia;
  NSButton *growl;
}

@property (nonatomic, retain) IBOutlet NSButton *scrobble;
@property (nonatomic, retain) IBOutlet NSButton *bindMedia;
@property (nonatomic, retain) IBOutlet NSButton *growl;

- (IBAction) changeScrobbleTo: (id) sender;
- (IBAction) changeBindMediaTo: (id) sender;
- (IBAction) changeGrowlTo: (id) sender;

@end
