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

@synthesize mainC, auth, playback, pandora, window;

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
  [self hideSpinner];
  [NSApp beginSheet: authSheet
     modalForWindow: window
      modalDelegate: self
     didEndSelector: NULL
        contextInfo: nil];
}

- (void) closeNewStationSheet {
  [NSApp endSheet:newStationSheet];
  [newStationSheet orderOut:self];
}

- (void) showNewStationSheet {
  [NSApp beginSheet: newStationSheet
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

- (void) cacheAuth: (NSString*) username : (NSString*) password {
  [[NSUserDefaults standardUserDefaults] setObject:username forKey:USERNAME_KEY];
  [Keychain setKeychainItem:username : password];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self showSpinner];

  // See http://developer.apple.com/mac/library/qa/qa2004/qa1340.html
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
      selector: @selector(receiveSleepNote:)
      name: NSWorkspaceWillSleepNotification object: NULL];

  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
      selector: @selector(receiveWakeNote:)
      name: NSWorkspaceDidWakeNotification object: NULL];

  NSString *savedUsername = [[NSUserDefaults standardUserDefaults]
      stringForKey:USERNAME_KEY];
  NSString *savedPassword = [Keychain getKeychainPassword: savedUsername];

  if (savedUsername != nil && savedPassword != nil) {
    [pandora authenticate: savedUsername : savedPassword];
  } else {
    [self showAuthSheet];
  }
}

- (void)applicationWillResignActive:(NSNotification *)aNotification {
  [mainC hideDrawer];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification {
  if ([pandora authToken] != nil) {
    [mainC showDrawer];
  }
}

- (void) receiveSleepNote: (NSNotification*) note {
  NSLog(@"receiveSleepNote: %@", [note name]);
}

- (void) receiveWakeNote: (NSNotification*) note {
  NSLog(@"receiveWakeNote: %@", [note name]);
}

@end
