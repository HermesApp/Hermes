//
//  PreferencesController.m
//  Hermes
//
//  Created by Alex Crichton on 4/29/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "PreferencesController.h"
#import "Scrobbler.h"
#import "AppleMediaKeyController.h"

@implementation PreferencesController

@synthesize bindMedia, scrobble;

- (void)windowDidBecomeMain:(NSNotification *)notification {
  NSInteger state;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  state = [defaults boolForKey:PLEASE_SCROBBLE] ? NSOnState : NSOffState;
  [scrobble setState:state];
  state = [defaults boolForKey:PLEASE_BIND_MEDIA] ? NSOnState : NSOffState;
  [bindMedia setState:state];
}

- (IBAction) changeScrobbleTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([scrobble state] == NSOnState) {
    [defaults setBool:YES forKey:PLEASE_SCROBBLE];
    [Scrobbler subscribe];
  } else {
    [defaults setBool:NO forKey:PLEASE_SCROBBLE];
    [Scrobbler unsubscribe];
  }
}

- (IBAction) changeBindMediaTo: (id) sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([bindMedia state] == NSOnState) {
    [defaults setBool:YES forKey:PLEASE_BIND_MEDIA];
    [AppleMediaKeyController bindKeys];
  } else {
    [defaults setBool:NO forKey:PLEASE_BIND_MEDIA];
    [AppleMediaKeyController unbindKeys];
  }
}

@end
