//
//  AuthController.m
//  Hermes
//
//  Created by Alex Crichton on 3/13/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "AuthController.h"
#import "HermesAppDelegate.h"

@implementation AuthController

- (id) init {
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(authenticationFinished:)
    name:@"hermes.authenticated"
    object:[[NSApp delegate] pandora]];

  return self;
}

- (void)authenticationFinished: (NSNotification *)aNotification {
  [[NSApp delegate] hideSpinner]; // Big app spinner
  [spinner setHidden:YES];        // Local login sheet spinner
  [spinner stopAnimation:nil];

  if ([[[NSApp delegate] pandora] authenticated]) {
    [self cancel:nil];
    [auth setHidden:YES];
    [[[NSApp delegate] mainC] afterAuthentication];

    if ([password stringValue] != nil && ![[password stringValue] isEqual:@""]) {
      [[NSApp delegate] cacheAuth:[username stringValue] : [password stringValue]];
    }
  } else {
    [self showAuth:nil];
    [error setHidden:NO];
  }
}

/* Cancel was hit, hide the sheet */
- (IBAction)cancel: (id)sender {
  [[NSApp delegate] closeAuthSheet];
  [error setHidden: YES];

  [auth setHidden:NO];
}

/* Login button in sheet hit, should authenticate */
- (IBAction)authenticate: (id)sender {
  [error setHidden: YES];
  [spinner setHidden:NO];
  [spinner startAnimation: sender];

  [[[NSApp delegate] pandora] authenticate:[username stringValue] : [password stringValue]];
}

/* Login button in main window hit, should show sheet */
- (IBAction)showAuth: (id)sender {
  [[NSApp delegate] showAuthSheet];
}

@end
