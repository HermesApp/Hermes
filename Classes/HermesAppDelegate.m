//
//  PithosAppDelegate.m
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "HermesAppDelegate.h"
#import "Keychain.h"

@implementation HermesAppDelegate

@synthesize window, authSheet, mainC, auth, playback, pandora;

- (id) init {
  pandora = [[Pandora alloc] init];
  return self;
}

- (void) dealloc {
  [pandora release];
  [super dealloc];
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                    hasVisibleWindows:(BOOL)flag {
  if (!flag) {
    [window makeKeyAndOrderFront:nil];
  }

  return YES;
}

- (void) closeAuthSheet {
  [NSApp endSheet:authSheet];
  [authSheet orderOut:self];
}

- (void) showAuthSheet {
  [NSApp beginSheet: authSheet
     modalForWindow: window
      modalDelegate: self
     didEndSelector: NULL
        contextInfo: nil];
}

- (void) showSpinner {
  [appLoading setHidden:NO];
  [appLoading startAnimation:nil];
}

- (void) hideSpinner {
  [appLoading setHidden:YES];
  [appLoading stopAnimation:nil];
}

- (BOOL) checkAuth: (NSString*) username : (NSString*) password {
  BOOL valid = [pandora authenticate:username : password];

  if (valid) {
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:USERNAME_KEY];
    [Keychain setKeychainItem:username : password];
  }

  return valid;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self showSpinner];

  NSString *savedUsername = [[NSUserDefaults standardUserDefaults]
      stringForKey:USERNAME_KEY];
  NSString *savedPassword = [Keychain getKeychainPassword: savedUsername];

  if ([self checkAuth: savedUsername : savedPassword]) {
    [mainC afterAuthentication];
  } else {
    [self showAuthSheet];
  }

  [self hideSpinner];
}

- (void)applicationWillResignActive:(NSNotification *)aNotification {
  [mainC hideDrawer];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification {
  if ([pandora authToken] != nil) {
    [mainC showDrawer];
  }
}

@end
