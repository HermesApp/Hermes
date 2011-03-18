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

  IBOutlet NSWindow *window;
  IBOutlet NSWindow *authSheet;
  IBOutlet NSWindow *newStationSheet;

  IBOutlet MainController *mainC;
  IBOutlet AuthController *auth;
  IBOutlet PlaybackController *playback;
}

@property (readonly) NSWindow *window;
@property (assign) MainController *mainC;
@property (assign) AuthController *auth;
@property (assign) PlaybackController *playback;
@property (retain) Pandora *pandora;

- (void) closeAuthSheet;
- (void) showAuthSheet;
- (void) closeNewStationSheet;
- (void) showNewStationSheet;
- (void) cacheAuth: (NSString*) username : (NSString*) password;
- (void) showSpinner;
- (void) hideSpinner;

@end
