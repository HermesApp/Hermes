#import <SPMediaKeyTap/SPMediaKeyTap.h>

#import "HermesAppDelegate.h"
#import "PreferencesController.h"

@implementation PreferencesController

- (void)windowDidBecomeMain:(NSNotification *)notification {
  NSString *last = PREF_KEY_VALUE(LAST_PREF_PANE);

  if ([last isEqual:@"playback"]) {
    [self setPreferenceView:playback as:@"playback"];
    [toolbar setSelectedItemIdentifier:@"playback"];
  } else if ([last isEqual:@"network"]) {
    [self setPreferenceView:network as:@"network"];
    [toolbar setSelectedItemIdentifier:@"network"];
  } else {
    [self setPreferenceView:general as:@"general"];
    [toolbar setSelectedItemIdentifier:@"general"];
  }
}

- (void) setPreferenceView:(NSView*) view as:(NSString*)name {
  NSView *container = [window contentView];
  if ([[container subviews] count] > 0) {
    NSView *prev_view = [[container subviews] objectAtIndex:0];
    if (prev_view == view) {
      return;
    }
    [container replaceSubview:prev_view with:view];
  } else {
    [container addSubview:view];
  }

  NSRect frame = [view frame];
  NSRect superFrame = [container frame];
  frame.size.width = NSWidth(superFrame);
  frame.size.height = NSHeight(superFrame);
  [view setFrame:frame];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:name forKey:LAST_PREF_PANE];
}

- (IBAction) showGeneral: (id) sender {
  [self setPreferenceView:general as:@"general"];
}

- (IBAction) showPlayback: (id) sender {
  [self setPreferenceView:playback as:@"playback"];
}

- (IBAction) showNetwork: (id) sender {
  [self setPreferenceView:network as:@"network"];
}

- (IBAction) bindMediaChanged: (id) sender {
  SPMediaKeyTap *mediaKeyTap = [[NSApp delegate] mediaKeyTap];
  if (PREF_KEY_BOOL(PLEASE_BIND_MEDIA)) {
    [mediaKeyTap startWatchingMediaKeys];
  } else {
    [mediaKeyTap stopWatchingMediaKeys];
  }
}

@end
