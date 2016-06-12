#import "AuthController.h"
#import "HermesAppDelegate.h"
#import "PlaybackController.h"
#import "StationsController.h"
#import "Notifications.h"

#define ROUGH_EMAIL_REGEX @"[^\\s@]+@[^\\s@]+\\.[^\\s@]+"

@implementation AuthController

- (id) init {
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

  [notificationCenter
    addObserver:self
    selector:@selector(authenticationSucceeded:)
    name:PandoraDidAuthenticateNotification
    object:nil];

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
  NSNotification *emptyNotification;
  [self controlTextDidChange:emptyNotification];
}

- (void) authenticationSucceeded: (NSNotification*) notification {
  [spinner setHidden:YES];
  [spinner stopAnimation:nil];

  HermesAppDelegate *delegate = [NSApp delegate];
  if (![[username stringValue] isEqualToString:@""]) {
    [delegate saveUsername:[username stringValue] password:[password stringValue]];
  }

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
  
  NSNotification *emptyNotification;
  [self controlTextDidChange:emptyNotification];
}

/* Log out the current session */
- (IBAction) logout: (id) sender {
  [password setStringValue:@""];
  HermesAppDelegate *delegate = [NSApp delegate];
  [[delegate pandora] logout];
}

- (void)controlTextDidChange:(NSNotification *)obj {
  NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ROUGH_EMAIL_REGEX];
  
  [login setEnabled:
   [spinner isHidden] &&
   [emailTest evaluateWithObject:[username stringValue]] &&
   ![[password stringValue] isEqualToString:@""]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  HermesAppDelegate *delegate = [NSApp delegate];

  if (![[delegate pandora] isAuthenticated]) {
    return NO;
  }

  return YES;
}

@end
