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

@synthesize window, authSheet, main, auth;

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

- (BOOL) checkAuth: (NSString*) username : (NSString*) password {
  return [main authenticate: username : password];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSString *savedUsername = [[NSUserDefaults standardUserDefaults]
      stringForKey:USERNAME_KEY];
  NSString *savedPassword = [Keychain getKeychainPassword: savedUsername];

  if (![main authenticate: savedUsername : savedPassword]) {
    [self showAuthSheet];
  }
}

@end
