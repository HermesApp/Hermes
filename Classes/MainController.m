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

- (id) init {
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationsLoaded:)
    name:@"hermes.stations"
    object:[[NSApp delegate] pandora]];

  return self;
}

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

    if ([[station stationId] isEqual: [cur stationId]]) {
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
      if ([lastPlayed isEqual: [cur stationId]]) {
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

- (void) stationsLoaded: (NSNotification*) not {
  [stationsTable reloadData];
  [[[NSApp delegate] playback] afterStationsLoaded];

  [self showDrawer];

  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];

  if ([self playingStation] != nil) {
    [self selectStation:[self playingStation]];
  } else if ([self playSavedStation]) {
    [selectStation setHidden:YES];
  }
}

- (void) showDrawer {
  [stations open];
}

- (void) hideDrawer {
  [stations close];
}

/* Called after the user has authenticated */
- (void) afterAuthentication {
  [selectStation setHidden:NO];
  [stationsTable setDataSource: self];

  [self refreshList:nil];
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

- (IBAction)refreshList: (id)sender {
  [stationsRefreshing setHidden:NO];
  [stationsRefreshing startAnimation:nil];
  [[self pandora] fetchStations];
}

@end
