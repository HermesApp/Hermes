//
//  MainController.m
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "MainController.h"
#import "Pandora.h"

@implementation MainController

- (id) init {
  pandora = [[Pandora alloc] init];
  return self;
}

- (IBAction) authenticate: (id)sender {
//  [pandora authenticate: [username stringValue]: [password stringValue]];
  [pandora authenticate: @"adcrichton@gmail.com": @"armageddon"];

  if ([pandora authToken] != nil && [pandora listenerID] != nil) {
    [authTokenLabel setStringValue: [pandora authToken]];
    [listenerIdLabel setStringValue: [pandora listenerID]];

    [pandora fetchStations];
    [stationsTable setDataSource: self];
    [stationsTable reloadData];
  }
}

- (IBAction)tableViewSelected: (id)sender {
  int row = [sender selectedRow];

  if (row != -1) {
    [pandora playStation: [[pandora stations] objectAtIndex:row]];
  }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [[pandora stations] count];
}

- (id)tableView:(NSTableView *)aTableView
        objectValueForTableColumn:(NSTableColumn *)aTableColumn
        row:(NSInteger)rowIndex {
  Station *s = [[pandora stations] objectAtIndex: rowIndex];

  if ([[aTableColumn identifier] isEqual: @"id"]) {
    return [s station_id];
  }

  return [s name];
}

@end
