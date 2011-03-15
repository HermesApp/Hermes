//
//  MainController.m
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "MainController.h"
#import "Pandora.h"
#import "HermesAppDelegate.h"

@implementation MainController

- (Pandora*) pandora {
  return [[NSApp delegate] pandora];
}

- (Station*) playingStation {
  return [[[NSApp delegate] playback] playing];
}

- (void) playStation: (Station*) station {
  [[[NSApp delegate] playback] playStation:station];
}

/* Part of the NSTableViewDataSource protocol */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [[[self pandora] stations] count];
}

/* Part of the NSTableViewDataSource protocol */
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex {

  return [[[[self pandora] stations] objectAtIndex: rowIndex] name];
}

/* Selects a station in the stations menu */
- (void) selectStation: (Station*) station {
  Station *cur;
  int i, index = -1;

  for (i = 0; i < [[[self pandora] stations] count]; i++) {
    cur = [[[self pandora] stations] objectAtIndex:i];

    if ([[station station_id] isEqual: [cur station_id]]) {
      index = i;
      break;
    }
  }

  if (index >= 0) {
    [stationsTable
      selectRowIndexes:[NSIndexSet indexSetWithIndex:i]
      byExtendingSelection:NO];
  }
}

/* Play the last saved station from the last launch */
- (BOOL) playSavedStation {
  NSString *lastPlayed = [[NSUserDefaults standardUserDefaults]
                          stringForKey:LAST_STATION_KEY];

  if (lastPlayed != nil) {
    Station *last = nil;

    for (Station *cur in [[self pandora] stations]) {
      if ([lastPlayed isEqual: [cur station_id]]) {
        last = cur;
        break;
      }
    }

    if (last != nil) {
      [self playStation: last];
      [self selectStation: last];
      return YES;
    }
  }

  return NO;
}

- (void) showDrawer {
  [stations open];
}

- (void) hideDrawer {
  [stations close];
}

/* Called after the user has authenticated */
- (void) afterAuthentication {
  [[NSApp delegate] showSpinner];

  [[self pandora] fetchStations];
  [stationsTable setDataSource: self];
  [stationsTable reloadData];
  [[[NSApp delegate] playback] afterStationsLoaded];

  [[NSApp delegate] hideSpinner];
  [self showDrawer];

  if (![self playSavedStation]) {
    [selectStation setHidden:NO];
  }
}

- (IBAction)tableViewSelected: (id)sender {
  Station *selected = nil;

  int row = [stationsTable selectedRow];

  if (row != -1) {
    selected = [[[self pandora] stations] objectAtIndex:row];
  } else {
    [self selectStation:[self playingStation]];
    return;
  }

  [selectStation setHidden:YES];
  [self playStation:selected];
}

@end
