#import "PreferencesController.h"
#import "Scrobbler.h"
#import "Growler.h"
#import "AppleMediaKeyController.h"

@implementation PreferencesController

- (void)windowDidBecomeMain:(NSNotification *)notification {
  NSInteger state;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  state = [defaults boolForKey:PLEASE_SCROBBLE] ? NSOnState : NSOffState;
  [scrobble setState:state];
  state = [defaults boolForKey:PLEASE_SCROBBLE_LIKES] ? NSOnState : NSOffState;
  [scrobbleLikes setState:state];
  state = [defaults boolForKey:ONLY_SCROBBLE_LIKED] ? NSOnState : NSOffState;
  [scrobbleOnlyLiked setState:state];
  state = [defaults boolForKey:PLEASE_BIND_MEDIA] ? NSOnState : NSOffState;
  [bindMedia setState:state];
  state = [defaults boolForKey:PLEASE_GROWL] ? NSOnState : NSOffState;
  [growl setState:state];
  state = [defaults boolForKey:PLEASE_GROWL_NEW] ? NSOnState : NSOffState;
  [growlNewSongs setState:state];
  state = [defaults boolForKey:PLEASE_GROWL_PLAY] ? NSOnState : NSOffState;
  [growlPlayPause setState:state];

  NSString *quality = [defaults objectForKey:DESIRED_QUALITY];
  [highQuality setState:NSOffState];
  [mediumQuality setState:NSOffState];
  [lowQuality setState:NSOffState];
  if ([quality isEqualToString:QUALITY_HIGH]) {
    [highQuality setState:NSOnState];
  } else if ([quality isEqualToString:QUALITY_LOW]) {
    [lowQuality setState:NSOnState];
  } else {
    [mediumQuality setState:NSOnState];
  }
  [self setPreferenceView:general];
}

- (void) setPreferenceView: (NSView*) view {
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
}

- (IBAction) changeScrobbleTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL selected = ([scrobble state] == NSOnState);

  [defaults setBool:selected forKey:PLEASE_SCROBBLE];
  [scrobbleLikes setEnabled:selected];
  [scrobbleOnlyLiked setEnabled:selected];

  if (selected) {
    [Scrobbler subscribe];
  } else {
    [Scrobbler unsubscribe];
  }
}

- (IBAction) changeScrobbleLikesTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool:([scrobbleLikes state] == NSOnState)
             forKey:PLEASE_SCROBBLE_LIKES];
}

- (IBAction) changeScrobbleOnlyLikedTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool:([scrobbleOnlyLiked state] == NSOnState)
             forKey:ONLY_SCROBBLE_LIKED];
}

- (IBAction) changeBindMediaTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([bindMedia state] == NSOnState) {
    [defaults setBool:YES forKey:PLEASE_BIND_MEDIA];
    [AppleMediaKeyController bindKeys];
  } else {
    [defaults setBool:NO forKey:PLEASE_BIND_MEDIA];
    [AppleMediaKeyController unbindKeys];
  }
}

- (IBAction) changeGrowlTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL selected = ([growl state] == NSOnState);

  [defaults setBool:selected forKey:PLEASE_GROWL];
  [growlNewSongs setEnabled:selected];
  [growlPlayPause setEnabled:selected];

  if (selected) {
    [Growler subscribe];
  } else {
    [Growler unsubscribe];
  }
}

- (IBAction) changeGrowlPlayPauseTo:(id)sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool:([growlPlayPause state] == NSOnState)
             forKey:PLEASE_GROWL_PLAY];
}

- (IBAction) changeGrowlNewSongTo:(id)sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool:([growlNewSongs state] == NSOnState)
             forKey:PLEASE_GROWL_NEW];
}

- (IBAction) changeQualityToLow:(id)sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:QUALITY_LOW forKey:DESIRED_QUALITY];
}

- (IBAction) changeQualityToMedium:(id)sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:QUALITY_MED forKey:DESIRED_QUALITY];
}

- (IBAction) changeQualityToHigh:(id)sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:QUALITY_HIGH forKey:DESIRED_QUALITY];
}

- (IBAction) showGeneral: (id) sender {
  [self setPreferenceView:general];
}

- (IBAction) showPlayback: (id) sender {
  [self setPreferenceView:playback];
}

@end
