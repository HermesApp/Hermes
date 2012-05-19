#import "StationsController.h"
#import "Pandora.h"
#import "HermesAppDelegate.h"
#import "PreferencesController.h"
#import "PlaybackController.h"
#import "StationController.h"

@implementation StationsController

- (id) init {
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationsLoaded:)
    name:@"hermes.stations"
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
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationRenamed:)
    name:@"hermes.station-renamed"
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

- (void) showDrawer {
  [stations open];
  [showStations setImage:[NSImage imageNamed:@"NSLeftFacingTriangleTemplate"]];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setValue:@"0" forKey:PLEASE_CLOSE_DRAWER];
}

- (void) hideDrawer {
  [stations close];
  [showStations setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setValue:@"1" forKey:PLEASE_CLOSE_DRAWER];
}

- (IBAction) toggleDrawer: (id) sender {
  if ([stations state] == NSDrawerOpenState) {
    [self hideDrawer];
  } else {
    [self showDrawer];
  }
}

- (void) reset {
  [self hideDrawer];
  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
}

- (int) stationIndex:(Station *)station {
  unsigned i;
  Station *cur;
  NSArray *arr = [[self pandora] stations];
  for (i = 0; i < [arr count]; i++) {
    cur = [arr objectAtIndex:i];

    if ([[station stationId] isEqual: [cur stationId]]) {
      return i;
    }
  }
  return -1;
}

/* Selects a station in the stations menu */
- (void) selectStation: (Station*) station {
  int index = [self stationIndex:station];

  if (index >= 0) {
    [stationsTable
     selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
     byExtendingSelection:NO];
  }
}

/* Play the last saved station from the last launch */
- (BOOL) playSavedStation {
  NSString *lastPlayed = [[NSUserDefaults standardUserDefaults]
                          stringForKey:LAST_STATION_KEY];

  if (lastPlayed == nil) {
    return NO;
  }
  Station *last = nil;

  for (Station *cur in [[self pandora] stations]) {
    if ([lastPlayed isEqual: [cur stationId]]) {
      last = cur;
      break;
    }
  }

  if (last != nil) {
    [[[NSApp delegate] playback] playStation:last];
    [self selectStation: last];
    return YES;
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

  NSArray *st = [[self pandora] stations];
  if ((NSUInteger) rowIndex >= [st count]) { return nil; }
  Station *s = [st objectAtIndex: rowIndex];
  if ([[aTableColumn identifier] isEqual:@"image"]) {
    if ([s isEqual:[self playingStation]]) {
      return [NSImage imageNamed:@"volume_up"];
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
  Station *s = item;
  return [s name];
}

/* ============================ Other callbacks */

- (void) stationCreated: (NSNotification*) not {
  Station *s = [[not userInfo] objectForKey:@"station"];
  [[NSApp delegate] closeNewStationSheet];

  [searchSpinner setHidden:YES];
  [searchSpinner stopAnimation:nil];
  [stationsTable reloadData];
  [self selectStation:s];
  [[[NSApp delegate] playback] playStation:s];
}

- (void) stationRemoved: (NSNotification*) not {
  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];
  [stationsTable reloadData];
}

- (void) stationRenamed: (NSNotification*) not {
  [stationsTable reloadData];
}

/* Called whenever stations finish loading from pandora */
- (void) stationsLoaded: (NSNotification*) not {
  [stationsTable reloadData];

  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];

  if ([self playingStation] == nil && ![self playSavedStation]) {
    [[NSApp delegate] setCurrentView:view];
  }
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (![defaults boolForKey:PLEASE_CLOSE_DRAWER] ||
      [defaults objectForKey:LAST_STATION_KEY] == nil) {
    [self showDrawer];
  }
}

/* Called whenever search results are received */
- (void) searchResultsLoaded: (NSNotification*) not {
  lastResults = [not userInfo];

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

/* ============================ Callbacks for IBActions and such */

/* Called after the user has authenticated */
- (void) show {
  [[NSApp delegate] showLoader];
  [self refreshList:nil];
}

/* Callback for when the play button is hit for a station */
- (IBAction)playSelected: (id)sender {
  Station *selected = [self selectedStation];

  if (selected == nil) {
    return;
  }

  [self selectStation:selected];
  [[[NSApp delegate] playback] playStation:selected];
  [stationsTable reloadData];
}

/* Callback for when the refresh stations button is hit */
- (IBAction)refreshList: (id)sender {
  [stationsRefreshing setHidden:NO];
  [stationsRefreshing startAnimation:nil];
  [[self pandora] fetchStations];
}

/* Callback for when the add station button is hit */
- (IBAction)addStation: (id)sender {
  [[NSApp delegate] showNewStationSheet];
  [search setStringValue:@""];
  lastResults = [NSDictionary dictionary];
  [results reloadData];
}

/* Callback for the search box on the create sheet */
- (IBAction)search: (id)sender {
  [errorIndicator setHidden:YES];
  [searchSpinner setHidden:NO];
  [searchSpinner startAnimation:nil];

  [[self pandora] search:[search stringValue]];
}

/* Callback for the cancel button is hit on the create sheet */
- (IBAction)cancelCreateStation: (id)sender {
  [[NSApp delegate] closeNewStationSheet];
}

/* Callback for the create button on the create sheet */
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

/* Callback for the dialog which is shown when deleting a station */
- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
    contextInfo:(void *)contextInfo {

  Station *selected = [self selectedStation];

  // -1 means that OK was hit (it's not the default
  if (returnCode != -1) {
    return;
  }

  if ([selected isEqual: [self playingStation]]) {
    [[[NSApp delegate] playback] playStation: nil];
    [[NSApp delegate] setCurrentView:view];
  }

  [stationsRefreshing setHidden:NO];
  [stationsRefreshing startAnimation:nil];
  [[self pandora] removeStation:[selected token]];
}

/* Callback for the delete button on the stations drawer */
- (IBAction)deleteSelected: (id)sender {
  Station *selected = [self selectedStation];

  if (selected == nil) {
    return;
  }

  NSAlert *alert =
    [NSAlert
      alertWithMessageText:@"Are you sure you want to delete this station?"
      defaultButton:@"Cancel"
      alternateButton:nil
      otherButton:@"OK"
      informativeTextWithFormat:@"You cannot undo this deletion"];
  [alert setAlertStyle:NSWarningAlertStyle];
  [alert setIcon:[NSImage imageNamed:@"error_icon"]];

  [alert beginSheetModalForWindow:[[NSApp delegate] window]
      modalDelegate:self
      didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
      contextInfo:NULL];
}

- (IBAction)editSelected:(id)sender {
  Station *s = [self selectedStation];
  if ([[s name] isEqualToString: @"QuickMix"]) return;
  [[[NSApp delegate] station] editStation: [self selectedStation]];
}

@end
