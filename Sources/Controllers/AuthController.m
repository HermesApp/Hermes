#import "AuthController.h"
#import "HermesAppDelegate.h"
#import "PlaybackController.h"
#import "StationsController.h"

@implementation AuthController

- (id) init {
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

  [notificationCenter
    addObserver:self
    selector:@selector(authenticationSucceeded:)
    name:@"hermes.authenticated"
    object:[[NSApp delegate] pandora]];

  [notificationCenter
   addObserver:self
   selector:@selector(controlTextDidChange:)
   name:NSControlTextDidChangeNotification
   object:username];

  [notificationCenter
   addObserver:self
   selector:@selector(controlTextDidChange:)
   name:NSControlTextDidChangeNotification
   object:password];

  return self;
}

- (void) authenticationFailed: (NSNotification*) notification
                        error: (NSString*) err {
  [spinner setHidden:YES];
  [spinner stopAnimation:nil];
  [self show];
  [error setHidden:NO];
  [errorText setHidden:NO];
  [errorText setStringValue:err];
  if ([username stringValue] == nil || [[username stringValue] isEqual:@""]) {
    [username becomeFirstResponder];
  } else {
    [password becomeFirstResponder];
  }
  [self controlTextDidChange:nil];
}

- (void) authenticationSucceeded: (NSNotification*) notification {
  [spinner setHidden:YES];
  [spinner stopAnimation:nil];

  if (![[username stringValue] isEqualToString:@""]) {
    [[NSApp delegate] cacheAuth:[username stringValue] : [password stringValue]];
  }

  HermesAppDelegate *delegate = [NSApp delegate];
  [[delegate stations] show];
  [PlaybackController setPlayOnStart:YES];
}

/* Login button in sheet hit, should authenticate */
- (IBAction) authenticate: (id) sender {
  [error setHidden: YES];
  [errorText setHidden: YES];
  [spinner setHidden:NO];
  [spinner startAnimation: sender];

  [[[NSApp delegate] pandora] authenticate:[username stringValue]
                                  password:[password stringValue]
                                   request:nil];
  [login setEnabled:NO];
}

/* Show the authentication view */
- (void) show {
  [[NSApp delegate] setCurrentView:view];
  [username becomeFirstResponder];

  [self controlTextDidChange:nil];
}

/* Log out the current session */
- (IBAction) logout: (id) sender {
  [password setStringValue:@""];
  HermesAppDelegate *delegate = [NSApp delegate];
  [[delegate pandora] logout];
}

- (void)controlTextDidChange:(NSNotification *)obj {
  [login setEnabled:
   [spinner isHidden] &&
   ![[username stringValue] isEqualToString:@""] &&
   ![[password stringValue] isEqualToString:@""]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  HermesAppDelegate *delegate = [NSApp delegate];

  if (![[delegate pandora] authenticated]) {
    return NO;
  }

  return YES;
}

@end
