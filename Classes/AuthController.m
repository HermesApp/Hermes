#import "AuthController.h"
#import "HermesAppDelegate.h"

@implementation AuthController

- (id) init {
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(authenticationSucceeded:)
    name:@"hermes.authenticated"
    object:[[NSApp delegate] pandora]];

  return self;
}

- (void) authenticationFailed: (NSNotification*) notification {
  [spinner setHidden:YES];
  [spinner stopAnimation:nil];
  [self show];
  [error setHidden:NO];
  if ([username stringValue] == nil || [[username stringValue] isEqual:@""]) {
    [username becomeFirstResponder];
  } else {
    [password becomeFirstResponder];
  }
  [login setEnabled:YES];
}

- (void) authenticationSucceeded: (NSNotification*) notification {
  [spinner setHidden:YES];
  [spinner stopAnimation:nil];

  if (![[username stringValue] isEqualToString:@""]) {
    [[NSApp delegate] cacheAuth:[username stringValue] : [password stringValue]];
  }

  HermesAppDelegate *delegate = [NSApp delegate];
  [[delegate stations] show];
}

/* Login button in sheet hit, should authenticate */
- (IBAction) authenticate: (id) sender {
  [error setHidden: YES];
  [spinner setHidden:NO];
  [spinner startAnimation: sender];

  [[[NSApp delegate] pandora] authenticate:[username stringValue]
                                          :[password stringValue]
                                          :nil];
  [login setEnabled:NO];
}

/* Show the authentication view */
- (void) show {
  [[NSApp delegate] setCurrentView:view];
  [username becomeFirstResponder];
  [login setEnabled:YES];
}

/* Log out the current session */
- (IBAction) logout: (id) sender {
  /* Pause playback */
  PlaybackController *playback = [[NSApp delegate] playback];
  Station *playing = [playback playing];
  if ([playing playing]) {
    [playback playpause:nil];
  }

  /* Remove our credentials */
  [[NSApp delegate] cacheAuth:@"" :@""];
  [self show];
}

@end
