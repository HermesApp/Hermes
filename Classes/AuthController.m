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

  if ([[NSApp delegate] checkAuth: [username stringValue] : [password stringValue]]) {
    [[NSApp delegate] closeAuthSheet];
    [auth setHidden:YES];
    [[[NSApp delegate] mainC] afterAuthentication];
  } else {
    [error setHidden: NO];
  }

  [spinner setHidden:YES];
  [spinner stopAnimation: sender];
}

/* Login button in main window hit, should show sheet */
- (IBAction)showAuth: (id)sender {
  [[NSApp delegate] showAuthSheet];
}

@end
