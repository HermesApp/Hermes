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

#ifdef MAC_OS_X_VERSION_10_6
@interface MainController : NSObject < NSTableViewDataSource, NSOutlineViewDataSource > {
#else
@interface MainController : NSObject {
#endif

  IBOutlet NSTextField *selectStation;
  IBOutlet NSDrawer *stations;
  IBOutlet NSTableView *stationsTable;
  IBOutlet NSProgressIndicator *stationsRefreshing;

  // New station things
  IBOutlet NSTextField *search;
  IBOutlet NSOutlineView *results;
  IBOutlet NSProgressIndicator *searchSpinner;
  IBOutlet NSImageView *errorIndicator;

  // Last known results
  NSDictionary *lastResults;
}

- (void) showDrawer;
- (void) hideDrawer;
- (void)afterAuthentication;

// Buttons at bottom of drawer
- (IBAction)deleteSelected: (id)sender;
- (IBAction)playSelected: (id)sender;
- (IBAction)refreshList: (id)sender;
- (IBAction)addStation: (id)sender;

// Actions from new station sheet
- (IBAction)search: (id)sender;
- (IBAction)cancelCreateStation: (id)sender;
- (IBAction)createStation: (id)sender;

@end
