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

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(loggedOut:)
    name:@"hermes.logged-out"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(searchResultsLoaded:)
    name:@"hermes.search-results"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationCreated:)
    name:@"hermes.station-created"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationRemoved:)
    name:@"hermes.station-removed"
    object:[[NSApp delegate] pandora]];

  return self;
}

/* ============================ Miscellaneous helpers */

- (Pandora*) pandora {
  return [[NSApp delegate] pandora];
}

- (Station*) playingStation {
  return [[[NSApp delegate] playback] playing];
}

- (Station*) selectedStation {
  int row = [stationsTable selectedRow];

  if (row < 0) {
    return nil;
  }

  return [[[self pandora] stations] objectAtIndex:row];
}

- (void) playStation: (Station*) station {
  [[[NSApp delegate] playback] playStation:station];
}

- (void) showDrawer {
  [stations open];
}

- (void) hideDrawer {
  [stations close];
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

/* ============================ NSTableViewDataSource protocol */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [[[self pandora] stations] count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex {

  Station *s = [[[self pandora] stations] objectAtIndex: rowIndex];
  if ([[aTableColumn identifier] isEqual:@"image"]) {
    if ([s isEqual:[self playingStation]]) {
      return [NSImage imageNamed:@"volume_up.png"];
    }

    return nil;
  }

  return [s name];
}

/* ============================ NSOutlineViewDataSource protocol */
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  if (item == nil) {
    return [[lastResults allKeys] objectAtIndex:index];
  }

  return [[lastResults objectForKey:item] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  return [lastResults objectForKey:item] != nil;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  if (item == nil) {
    return [[lastResults allKeys] count];
  }

  return [[lastResults objectForKey:item] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
  objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {

  if ([item isKindOfClass:[NSString class]]) {
    return item;
  }
  return [item name];
}

/* ============================ Other callbacks */

- (void) loggedOut: (NSNotification*) not {
  [self hideDrawer];
}

- (void) stationCreated: (NSNotification*) not {
  [[NSApp delegate] closeNewStationSheet];

  [searchSpinner setHidden:YES];
  [searchSpinner stopAnimation:nil];
  [self refreshList:nil];
}

- (void) stationRemoved: (NSNotification*) not {
  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];
  [stationsTable reloadData];
}

/* Called whenever stations finish loading from pandora */
- (void) stationsLoaded: (NSNotification*) not {
  [stationsTable reloadData];
  [[[NSApp delegate] playback] afterStationsLoaded];

  [self showDrawer];

  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];

  if ([self playingStation] == nil && [self playSavedStation]) {
    [selectStation setHidden:YES];
  }
}

/* Called whenever search results are received */
- (void) searchResultsLoaded: (NSNotification*) not {
  if (lastResults) {
    [lastResults release];
  }

  lastResults = [not userInfo];
  [lastResults retain];

  [searchSpinner setHidden:YES];
  [searchSpinner stopAnimation:nil];
  [results reloadData];

  for (NSString *string in [lastResults allKeys]) {
    if ([[lastResults objectForKey:string] count] > 0) {
      [results expandItem:string];
    } else {
      [results collapseItem:string];
    }
  }
}

/* Called after the user has authenticated */
- (void) afterAuthentication {
  [selectStation setHidden:NO];
  [stationsTable setDataSource: self];

  [self refreshList:nil];
}

- (IBAction)playSelected: (id)sender {
  Station *selected = [self selectedStation];

  if (selected == nil) {
    return;
  }

  [self selectStation:selected];
  [selectStation setHidden:YES];
  [self playStation:selected];
  [stationsTable reloadData];
}

- (IBAction)refreshList: (id)sender {
  [stationsRefreshing setHidden:NO];
  [stationsRefreshing startAnimation:nil];
  [[self pandora] fetchStations];
}

- (IBAction)addStation: (id)sender {
  if (![[self pandora] authenticated]) {
    return;
  }

  [[NSApp delegate] showNewStationSheet];
  [results setDataSource:self];
  [results reloadData];
}

- (IBAction)search: (id)sender {
  [errorIndicator setHidden:YES];
  [searchSpinner setHidden:NO];
  [searchSpinner startAnimation:nil];

  [[self pandora] search:[search stringValue]];
}

- (IBAction)cancelCreateStation: (id)sender {
  [[NSApp delegate] closeNewStationSheet];
}

- (IBAction)createStation: (id)sender {
  [errorIndicator setHidden:YES];
  id item = [results itemAtRow:[results selectedRow]];

  if (![item isKindOfClass:[SearchResult class]]) {
    [errorIndicator setHidden:NO];
    return;
  }

  SearchResult *result = item;

  [searchSpinner setHidden:NO];
  [searchSpinner startAnimation:nil];

  [[self pandora] createStation:[result value]];
}

- (IBAction)deleteSelected: (id)sender {
  Station *selected = [self selectedStation];

  if (selected == nil) {
    return;
  }

  NSAlert *alert =
  [NSAlert
   alertWithMessageText:@"Are you sure?"
   defaultButton:@"Cancel"
   alternateButton:nil
   otherButton:@"OK"
   informativeTextWithFormat:@"You cannot undo this deletion"];
  [alert setAlertStyle:NSWarningAlertStyle];
  [alert setIcon:[NSImage imageNamed:@"error_icon.png"]];

  // -1 means that OK was hit (it's not the default
  if ([alert runModal] != -1) {
    return;
  }

  [stationsRefreshing setHidden:NO];
  [stationsRefreshing startAnimation:nil];
  [[self pandora] removeStation:[selected stationId]];
}

@end
