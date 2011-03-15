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
#import "PlaybackController.h"
#import "Pandora.h"

@interface HermesAppDelegate : NSObject <NSApplicationDelegate> {
  Pandora *pandora;

  IBOutlet NSProgressIndicator *appLoading;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSWindow *authSheet;
@property (assign) IBOutlet MainController *mainC;
@property (assign) IBOutlet AuthController *auth;
@property (assign) IBOutlet PlaybackController *playback;
@property (retain) Pandora *pandora;

- (void) closeAuthSheet;
- (void) showAuthSheet;
- (BOOL) checkAuth: (NSString*) username : (NSString*) password;
- (void) showSpinner;
- (void) hideSpinner;

@end
