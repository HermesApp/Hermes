/**
 * @file PreferencesController.h
 * @brief Headers for the PreferencesController class and preferences keys
 *        which are set from it
 */

/* If these are changed, then the xib also needs to be updated */
#define PLEASE_BIND_MEDIA          @"pleaseBindMedia"
#define PLEASE_SCROBBLE            @"pleaseScrobble"
#define PLEASE_SCROBBLE_LIKES      @"pleaseScrobbleLikes"
#define ONLY_SCROBBLE_LIKED        @"onlyScrobbleLiked"
#define PLEASE_GROWL               @"pleaseGrowl"
#define PLEASE_GROWL_NEW           @"pleaseGrowlNew"
#define PLEASE_GROWL_PLAY          @"pleaseGrowlPlay"
#define PLEASE_CLOSE_DRAWER        @"pleaseCloseDrawer"
#define DRAWER_WIDTH               @"drawerWidth"
#define HIST_DRAWER_WIDTH          @"histDrawerWidth"
#define DESIRED_QUALITY            @"audioQuality"
#define LAST_PREF_PANE             @"lastPrefPane"
#define ENABLED_PROXY              @"enabledProxy"
#define PROXY_HTTP_HOST            @"httpProxyHost"
#define PROXY_HTTP_PORT            @"httpProxyPort"
#define PROXY_SOCKS_HOST           @"socksProxyHost"
#define PROXY_SOCKS_PORT           @"socksProxyPort"
#define PROXY_AUDIO                @"proxyAudio"
#define OPEN_DRAWER                @"openDrawer"
#define SORT_STATIONS              @"sortStations"
#define GROWL_TYPE                 @"notificationType"
#define STATUS_BAR_ICON            @"statusBarIcon"
#define STATUS_BAR_ICON_BNW        @"statusBarIconBlackWhite"
#define ALWAYS_ON_TOP              @"alwaysOnTop"
#define PAUSE_ON_SCREENSAVER_START @"pauseOnScreensaverStart"
#define PLAY_ON_SCREENSAVER_STOP   @"playOnScreensaverStop"
#define PAUSE_ON_SCREEN_LOCK       @"pauseOnScreenLock"
#define PLAY_ON_SCREEN_UNLOCK      @"playOnScreenUnlock"

/* If observing a value, then the method which is implemented is:
   observeValueForKeyPath:(NSString*) ofObject:(id) change:(NSDictionary*)
                  context:(void*) */
#define PREFERENCES              [NSUserDefaults standardUserDefaults]
#define PREF_KEY_VALUE(x)        [PREFERENCES valueForKey:(x)]
#define PREF_KEY_BOOL(x)         [PREFERENCES boolForKey:(x)]
#define PREF_KEY_INT(x)          [PREFERENCES integerForKey:(x)]
#define PREF_KEY_SET_BOOL(x, y)  [PREFERENCES setBool:y forKey:x]
#define PREF_KEY_SET_INT(x, y)   [PREFERENCES setInteger:y forKey:x]

#define QUALITY_HIGH 0
#define QUALITY_MED  1
#define QUALITY_LOW  2

#define PROXY_SYSTEM 0
#define PROXY_HTTP   1
#define PROXY_SOCKS  2

#define SORT_DATE_ASC 0
#define SORT_DATE_DSC 1
#define SORT_NAME_ASC 2
#define SORT_NAME_DSC 3

#define GROWL_TYPE_GROWL 0
#define GROWL_TYPE_OSX   1

@interface PreferencesController : NSObject <NSWindowDelegate> {
  IBOutlet NSToolbar *toolbar;
  IBOutlet NSView *general;
  IBOutlet NSView *playback;
  IBOutlet NSView *network;

  IBOutlet NSButton *notificationEnabled;
  IBOutlet NSPopUpButton *notificationType;
  IBOutlet NSWindow *window;

  NSArray *itemIdentifiers;
}

/* Selecting views */
- (IBAction) showGeneral: (id) sender;
- (IBAction) showPlayback: (id) sender;
- (IBAction) showNetwork: (id) sender;

- (IBAction) bindMediaChanged: (id) sender;
- (IBAction) show: (id) sender;

@end
