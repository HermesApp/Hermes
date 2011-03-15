//
//  PithosAppDelegate.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MainController.h"
#import "AuthController.h"

#define USERNAME_KEY (@"pandora.username")

@interface HermesAppDelegate : NSObject <NSApplicationDelegate> {
  NSWindow *window;
  NSWindow *authSheet;

  MainController *main;
  AuthController *auth;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSWindow *authSheet;
@property (retain) IBOutlet MainController *main;
@property (retain) IBOutlet AuthController *auth;

- (void) closeAuthSheet;
- (void) showAuthSheet;
- (BOOL) checkAuth: (NSString*) username : (NSString*) password;

@end
