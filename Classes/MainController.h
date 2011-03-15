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
  IBOutlet NSTextField *selectStation;
  IBOutlet NSDrawer *stations;
  IBOutlet NSTableView *stationsTable;
}

- (void) showDrawer;
- (void) hideDrawer;
- (void)afterAuthentication;
- (IBAction)tableViewSelected: (id)sender;

@end
