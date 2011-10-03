#import "PreferencesController.h"
#import "Scrobbler.h"
#import "Growler.h"
#import "AppleMediaKeyController.h"

@implementation PreferencesController

@synthesize bindMedia, scrobble, growl;

- (void)windowDidBecomeMain:(NSNotification *)notification {
  NSInteger state;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  state = [defaults boolForKey:PLEASE_SCROBBLE] ? NSOnState : NSOffState;
  [scrobble setState:state];
  state = [defaults boolForKey:PLEASE_BIND_MEDIA] ? NSOnState : NSOffState;
  [bindMedia setState:state];
  state = [defaults boolForKey:PLEASE_GROWL] ? NSOnState : NSOffState;
  [growl setState:state];
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

@end
