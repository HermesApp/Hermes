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

- (IBAction)cancel: (id)sender {
  [[NSApp delegate] closeAuthSheet];
  [error setHidden: YES];
}

- (IBAction)authenticate: (id)sender {
  [error setHidden: YES];
  [spinner setHidden:NO];
  [spinner startAnimation: sender];

  if ([[NSApp delegate] checkAuth: [username stringValue] : [password stringValue]]) {
    [[NSApp delegate] closeAuthSheet];
  } else {
    [error setHidden: NO];
  }

  [spinner setHidden:YES];
  [spinner stopAnimation: sender];
}

- (IBAction)showAuth: (id)sender {
  [[NSApp delegate] showAuthSheet];
}

@end
