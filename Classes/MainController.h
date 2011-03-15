//
//  MainController.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "Pandora.h"
#import "Station.h"

@interface MainController : NSObject < NSTableViewDataSource > {
  IBOutlet NSButton *auth;
  IBOutlet NSTextField *selectStation;
  IBOutlet NSProgressIndicator *songLoadingProgress;

  IBOutlet NSDrawer *stations;
  IBOutlet NSTableView *stationsTable;

  // Playback items
  IBOutlet NSTextField *progressLabel;
  IBOutlet NSTextField *artistLabel;
  IBOutlet NSTextField *songLabel;

  IBOutlet NSProgressIndicator *playbackProgress;
  IBOutlet NSImageView *art;

  IBOutlet NSToolbarItem *playpause;
  IBOutlet NSToolbarItem *next;

  NSTimer *progressUpdateTimer;
  Pandora *pandora;
  Station *playing;
}

- (BOOL)authenticate: (NSString*) username : (NSString*) password;

- (IBAction)tableViewSelected: (id)sender;

- (IBAction)playpause: (id)sender;
- (IBAction)next: (id)sender;

- (IBAction)auth: (id)sender;
@end
