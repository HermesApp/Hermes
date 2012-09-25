#import "FileReader.h"
#import "HermesAppDelegate.h"
#import "Pandora.h"
#import "Pandora/Station.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "StationController.h"
#import "StationsController.h"
#import "HermesAppDelegate.h"

#define SORT_NAME 0
#define SORT_DATE 1

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
    selector:@selector(genreStationsLoaded:)
    name:@"hermes.genre-stations"
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

  if (row < 0 || (unsigned) row >= [[[self pandora] stations] count]) {
    return nil;
  }

  return [[self pandora] stations][row];
}

- (void) showDrawer {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSSize s;
  s.height = 100;
  s.width = [defaults integerForKey:DRAWER_WIDTH];
  [stations open];
  [stations setContentSize:s];
}

- (void) hideDrawer {
  [stations close];
}

- (void) reset {
  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
}

- (int) stationIndex:(Station *)station {
  unsigned i;
  Station *cur;
  NSArray *arr = [[self pandora] stations];
  for (i = 0; i < [arr count]; i++) {
    cur = arr[i];

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
  __block Station *last = nil;

  for (Station *cur in [[self pandora] stations]) {
    if ([lastPlayed isEqual: [cur stationId]]) {
      last = cur;
      break;
    }
  }
  if (last == nil) return NO;

  /* Restore station saved state on application startup */
  static int tried_restore = 0;
  if (!tried_restore) {
    tried_restore = 1;
    NSString *saved_state =
      [[NSApp delegate] stateDirectory:@"station.savestate"];
    if (saved_state != nil) {
      reader = [FileReader readerForFile:saved_state
                       completionHandler:^(NSData *data, NSError *err) {
        if (err == nil) {
          Station *s = [NSKeyedUnarchiver unarchiveObjectWithFile:saved_state];
          if ([last isEqual:s]) {
            last = s;
            [last setRadio:[self pandora]];
          }
        }
        [self selectStation: last];
        [[[NSApp delegate] playback] playStation:last];
        return;
      }];
      [reader start];
      return YES;
    }
  }
  [self selectStation: last];
  [[[NSApp delegate] playback] playStation:last];
  return YES;
}

/* ============================ NSDrawerDelegate protocol */

- (NSSize) drawerWillResizeContents:(NSDrawer*) drawer toSize:(NSSize) size {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:size.width forKey:DRAWER_WIDTH];
  return size;
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
  Station *s = st[rowIndex];
  if ([[aTableColumn identifier] isEqual:@"image"]) {
    if ([s isEqual:[self playingStation]]) {
      return [NSImage imageNamed:@"volume_up"];
    }

    return nil;
  }

  return [s name];
}

/* ============================ NSOutlineViewDataSource protocol */
- (id)outlineView:(NSOutlineView*)oview child:(NSInteger)index ofItem:(id)item {
  if (oview == results) {
    if (item == nil) {
      return [lastResults allKeys][index];
    }

    return lastResults[item][index];
  }

  if (item == nil) {
    return genreResults[index];
  }
  return item[@"stations"][index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  if (outlineView == results) {
    return lastResults[item] != nil;
  } else {
    return item[@"categoryName"] != nil;
  }
}

- (NSInteger)outlineView:(NSOutlineView*)oview numberOfChildrenOfItem:(id)item {
  if (oview == results) {
    if (item == nil) {
      return [[lastResults allKeys] count];
    }

    return [lastResults[item] count];
  }

  if (item == nil) {
    return [genreResults count];
  }
  return [item[@"stations"] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
  objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
  if (outlineView == results) {
    if ([item isKindOfClass:[NSString class]]) {
      return item;
    }
    Station *s = item;
    return [s name];
  }

  NSString *str = item[@"categoryName"];
  if (str != nil) return str;
  return item[@"stationName"];
}

/* ============================ Other callbacks */

- (void) stationCreated: (NSNotification*) not {
  Station *s = [not userInfo][@"station"];
  [[NSApp delegate] closeNewStationSheet];

  [searchSpinner setHidden:YES];
  [searchSpinner stopAnimation:nil];
  [genreSpinner setHidden:YES];
  [genreSpinner stopAnimation:nil];
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

- (void) applySort {
  Pandora *p = [self pandora];
  Station *selected = [self selectedStation];
  [p applySort:PREF_KEY_INT(SORT_STATIONS)];
  if (selected != nil) {
    [self selectStation:selected];
  }
  [stationsTable reloadData];
}

/* Called whenever stations finish loading from pandora */
- (void) stationsLoaded: (NSNotification*) not {
  [self applySort];
  [stationsTable reloadData];

  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];

  if ([self playingStation] == nil && ![self playSavedStation]) {
    [[NSApp delegate] setCurrentView:view];
  }
  [[NSApp delegate] handleDrawer];

  switch (PREF_KEY_INT(SORT_STATIONS)) {
    case SORT_NAME_ASC:
    case SORT_NAME_DSC:
      [sort setSelectedSegment:SORT_NAME];
      break;

    case SORT_DATE_ASC:
    case SORT_DATE_DSC:
    default:
      [sort setSelectedSegment:SORT_DATE];
      break;
  }
}

/* Called whenever search results are received */
- (void) searchResultsLoaded: (NSNotification*) not {
  lastResults = [not userInfo];

  [searchSpinner setHidden:YES];
  [searchSpinner stopAnimation:nil];
  [results reloadData];

  for (NSString *string in [lastResults allKeys]) {
    if ([lastResults[string] count] > 0) {
      [results expandItem:string];
    } else {
      [results collapseItem:string];
    }
  }
}

- (void) genreStationsLoaded: (NSNotification*) not {
  genreResults = [not userInfo][@"categories"];
  [genres reloadData];
  [genreSpinner stopAnimation:nil];
  [genreSpinner setHidden:YES];
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
  [search setStringValue:@""];
  lastResults = @{};
  [results reloadData];
  [[NSApp delegate] showNewStationSheet];
  [search becomeFirstResponder];
  [[self pandora] genreStations];
  [genreSpinner startAnimation:nil];
  [genreSpinner setHidden:NO];
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

/* Callback for creating a station by genre */
- (IBAction) createStationGenre:(id)sender {
  id item = [genres itemAtRow:[genres selectedRow]];
  NSString *token = item[@"stationToken"];
  if (token == nil) return;

  [genreSpinner setHidden:NO];
  [genreSpinner startAnimation:nil];
  [[self pandora] createStation:token];
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
  if (s == nil || [[s name] isEqualToString: @"QuickMix"]) return;
  StationController *c = [(HermesAppDelegate*)[NSApp delegate] station];
  [c editStation:s];
}

- (IBAction) toggleSort:(id)sender {
  int cur = PREF_KEY_INT(SORT_STATIONS);
  switch ([sender selectedSegment]) {
    case SORT_NAME:
      PREF_KEY_SET_INT(SORT_STATIONS, cur == SORT_NAME_ASC ? SORT_NAME_DSC :
                                                             SORT_NAME_ASC);
      break;
    case SORT_DATE:
      PREF_KEY_SET_INT(SORT_STATIONS, cur == SORT_DATE_ASC ? SORT_DATE_DSC :
                                                             SORT_DATE_ASC);
      break;
  }
  [self applySort];
  [stationsTable reloadData];
}

@end
