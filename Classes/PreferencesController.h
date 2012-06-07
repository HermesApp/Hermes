/**
 * @file PreferencesController.h
 * @brief Headers for the PreferencesController class and preferences keys
 *        which are set from it
 */

/* If these are changed, then the xib also needs to be updated */
#define PLEASE_BIND_MEDIA     @"pleaseBindMedia"
#define PLEASE_SCROBBLE       @"pleaseScrobble"
#define PLEASE_SCROBBLE_LIKES @"pleaseScrobbleLikes"
#define ONLY_SCROBBLE_LIKED   @"onlyScrobbleLiked"
#define PLEASE_GROWL          @"pleaseGrowl"
#define PLEASE_GROWL_NEW      @"pleaseGrowlNew"
#define PLEASE_GROWL_PLAY     @"pleaseGrowlPlay"
#define PLEASE_CLOSE_DRAWER   @"pleaseCloseDrawer"
#define DRAWER_WIDTH          @"drawerWidth"
#define DESIRED_QUALITY       @"audioQuality"
#define LAST_PREF_PANE        @"lastPrefPane"

/* If observing a value, then the method which is implemented is:
   observeValueForKeyPath:(NSString*) ofObject:(id) change:(NSDictionary*)
                  context:(void*) */
#define PREF_PATH(name) (@"values." name)
#define PREF_CONTROLLER [NSUserDefaultsController sharedUserDefaultsController]
#define PREF_OBSERVE_VALUE(x, y) [PREF_CONTROLLER addObserver:(x)              \
    forKeyPath:PREF_PATH(y)  options:NSKeyValueObservingOptionOld context:nil];
#define PREF_UNOBSERVE_VALUES(x, y) [PREF_CONTROLLER removeObserver:(x)        \
    forKeyPath:PREF_PATH(y) context:nil]
#define PREF_KEY_VALUE(x) [[PREF_CONTROLLER values] valueForKey:(x)]
#define PREF_KEY_BOOL(x) [(PREF_KEY_VALUE(x)) boolValue]

#define QUALITY_HIGH 0
#define QUALITY_MED  1
#define QUALITY_LOW  2

@interface PreferencesController : NSObject <NSWindowDelegate> {
  IBOutlet NSToolbar *toolbar;
  IBOutlet NSView *general;
  IBOutlet NSView *playback;
  IBOutlet NSWindow *window;
}

- (IBAction) showGeneral: (id) sender;
- (IBAction) showPlayback: (id) sender;

@end
