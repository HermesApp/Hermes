#import <SPMediaKeyTap/SPMediaKeyTap.h>

#import "HermesAppDelegate.h"
#import "PreferencesController.h"

@implementation PreferencesController

- (void)windowDidBecomeMain:(NSNotification *)notification {
  /* See HermesAppDelegate#updateStatusBarIcon */
  [window setCanHide:NO];

  NSString *last = PREF_KEY_VALUE(LAST_PREF_PANE);
  if (NSClassFromString(@"NSUserNotification") != nil) {
    [notificationEnabled setTitle:@""];
    [notificationType setHidden:NO];
  }

  if (itemIdentifiers == nil) {
    itemIdentifiers = [[toolbar items] valueForKey:@"itemIdentifier"];
  }

  if ([last isEqual:@"playback"]) {
    [toolbar setSelectedItemIdentifier:@"playback"];
    [self setPreferenceView:playback as:@"playback"];
  } else if ([last isEqual:@"network"]) {
    [toolbar setSelectedItemIdentifier:@"network"];
    [self setPreferenceView:network as:@"network"];
  } else {
    [toolbar setSelectedItemIdentifier:@"general"];
    [self setPreferenceView:general as:@"general"];
  }
}

- (void) setPreferenceView:(NSView*) view as:(NSString*)name {
  NSView *container = [window contentView];
  if ([[container subviews] count] > 0) {
    NSView *prev_view = [container subviews][0];
    if (prev_view == view) {
      return;
    }
    [prev_view removeFromSuperviewWithoutNeedingDisplay];
  }

  NSRect frame = [view bounds];
  frame.origin.y = NSHeight([container frame]) - NSHeight([view bounds]);
  [view setFrame:frame];
  [view setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
  [container addSubview:view];
  [window setInitialFirstResponder:view];

  NSRect windowFrame = [window frame];
  NSRect contentRect = [window contentRectForFrameRect:windowFrame];
  windowFrame.size.height = NSHeight(frame) + NSHeight(windowFrame) - NSHeight(contentRect);
  windowFrame.size.width = NSWidth(frame);
  windowFrame.origin.y = NSMaxY([window frame]) - NSHeight(windowFrame);
  [window setFrame:windowFrame display:YES animate:YES];

  NSUInteger toolbarItemIndex = [itemIdentifiers indexOfObject:name];
  NSString *title = @"Preferences";
  if (toolbarItemIndex != NSNotFound) {
    title = [[toolbar items][toolbarItemIndex] label];
  }
  [window setTitle:title];

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

- (IBAction) show: (id) sender {
  [window makeKeyAndOrderFront:sender];
}

@end
