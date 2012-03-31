#import "PreferencesController.h"
#import "Scrobbler.h"
#import "Growler.h"
#import "AppleMediaKeyController.h"

@implementation PreferencesController

@synthesize bindMedia, scrobble, scrobbleLikes, scrobbleOnlyLiked, growl,
            growlNewSongs, growlPlayPause;

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
}

- (IBAction) changeScrobbleTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([scrobble state] == NSOnState) {
    [defaults setBool:YES forKey:PLEASE_SCROBBLE];
    [Scrobbler subscribe];
  } else {
    [defaults setBool:NO forKey:PLEASE_SCROBBLE];
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

  if ([growl state] == NSOnState) {
    [defaults setBool:YES forKey:PLEASE_GROWL];
    [Growler subscribe];
  } else {
    [defaults setBool:NO forKey:PLEASE_GROWL];
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

@end
