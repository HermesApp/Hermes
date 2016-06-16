#import "FileReader.h"
#import "HermesAppDelegate.h"
#import "Pandora.h"
#import "Pandora/Station.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "StationController.h"
#import "StationsController.h"
#import "HermesAppDelegate.h"
#import "Notifications.h"

#define SORT_NAME 0
#define SORT_DATE 1

@implementation StationsController

- (id) init {
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationsLoaded:)
    name:PandoraDidLoadStationsNotification
    object:nil];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(searchResultsLoaded:)
    name:PandoraDidLoadSearchResultsNotification
    object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(genreStationsLoaded:)
    name:PandoraDidLoadGenreStationsNotification
    object:nil];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationCreated:)
    name:PandoraDidCreateStationNotification
    object:nil];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationRemoved:)
    name:PandoraDidDeleteStationNotification
    object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationRemoved:)
    name:PandoraDidLogOutNotification
    object:nil];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(stationRenamed:)
    name:PandoraDidDeleteFeedbackNotification
    object:nil];

  return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  if (![[self pandora] isAuthenticated]) {
    return NO;
  }
  
  SEL action = [menuItem action];
  if (action == @selector(editSelected:) || action == @selector(deleteSelected:)) {
    Station *s = [self selectedStation];
    if (s == nil || s.isQuickMix) return NO;
  }

  return YES;
}

#pragma mark - Miscellaneous helpers

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
  [self focus];
}

- (void) hideDrawer {
  [stations close];
}

- (void) reset {
  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
}

- (void) focus {
  [[stations parentWindow] makeFirstResponder:stationsTable];
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
    [stationsTable scrollRowToVisible:index];
    [self tableViewSelectionDidChange:nil];
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

#pragma mark - NSDrawerDelegate

- (NSSize) drawerWillResizeContents:(NSDrawer*) drawer toSize:(NSSize) size {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:size.width forKey:DRAWER_WIDTH];
  return size;
}

- (void)drawerWillClose:(NSNotification *)notification {
  PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_NONE_STA);
}

#pragma mark - NSTableViewDataSource protocol

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
      static NSImage *playingImage;
      if (playingImage == nil) {
        playingImage = [[NSImage imageNamed:@"volume_up"] copy];
        [playingImage setTemplate:YES];
      }
      return playingImage;
    }

    return nil;
  }

  return [s name];
}

#pragma mark - NSTableViewDelegate protocol

- (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString {
  if (searchString == nil && [[event characters] isEqualToString:@" "]) {
    [[[NSApp delegate] playback] playpause:nil];
  }
  
  return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  Station *s = [self selectedStation];

  BOOL editableStationSelected = (s != nil && !s.isQuickMix);
  [editStationButton setEnabled:editableStationSelected];
  [deleteStationButton setEnabled:editableStationSelected];
  [playStationButton setEnabled:(s != nil)];
}

#pragma mark -  NSOutlineViewDataSource protocol

- (id)outlineView:(NSOutlineView*)oview child:(NSInteger)index ofItem:(id)item {
  if (oview == results) {
    if (item == nil) {
      return [[lastResults allKeys] sortedArrayUsingSelector:@selector(compare:)][index];
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

#pragma mark - NSOutlineViewDelegate
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
  if (outlineView == results)
    return [item isKindOfClass:[NSString class]];
  else if (outlineView == genres)
    return [item isKindOfClass:[NSDictionary class]] && item[@"categoryName"] != nil;
  return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
  return ![self outlineView:outlineView isGroupItem:item];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
  NSOutlineView *outlineView = [notification object];
  [[outlineView target] setEnabled:[outlineView selectedRow] != -1];
}

#pragma mark - Other callbacks

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
  [stationsTable deselectAll:nil];
  [stationsTable reloadData];
}

- (void) stationRenamed: (NSNotification*) not {
  [stationsTable reloadData];
}

- (void) sortStations {
  Pandora *p = [self pandora];
  Station *selected = [self selectedStation];
  [p sortStations:PREF_KEY_INT(SORT_STATIONS)];
  if (selected != nil) {
    [self selectStation:selected];
  }
  [stationsTable reloadData];
}

/* Called whenever stations finish loading from pandora */
- (void) stationsLoaded: (NSNotification*) not {
  [self sortStations];
  [stationsTable reloadData];

  [stationsRefreshing setHidden:YES];
  [stationsRefreshing stopAnimation:nil];

  if ([self playingStation] == nil && ![self playSavedStation]) {
    [[NSApp delegate] setCurrentView:chooseStationView];
    [[NSApp delegate] showStationsDrawer:nil];
  }
  [[NSApp delegate] handleDrawer];

  BOOL isAscending = YES;
  NSInteger otherSegment = SORT_DATE;
  switch (PREF_KEY_INT(SORT_STATIONS)) {
    case SORT_NAME_DSC:
      isAscending = NO;
    case SORT_NAME_ASC:
      [sort setSelectedSegment:SORT_NAME];
      otherSegment = SORT_DATE;
      break;

    case SORT_DATE_DSC:
      isAscending = NO;
    case SORT_DATE_ASC:
    default:
      [sort setSelectedSegment:SORT_DATE];
      otherSegment = SORT_NAME;
      break;
  }
  [sort setImage:nil forSegment:otherSegment];
  [sort setImage:
   [NSImage imageNamed:isAscending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"] forSegment:[sort selectedSegment]];
}

/* Called whenever search results are received */
- (void) searchResultsLoaded: (NSNotification*) not {
  if (![not.object isEqualToString:[search stringValue]])
    return;

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
  NSArray *categories = [not userInfo][@"categories"];
  NSMutableArray *mutableCategories = [[NSMutableArray alloc] initWithCapacity:[categories count]];
  for (NSDictionary *category in categories) {
    NSMutableDictionary *mutableCategory = [category mutableCopy];
    mutableCategory[@"stations"] = [category[@"stations"] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull s1, id  _Nonnull s2) {
      return [s1[@"stationName"] localizedStandardCompare:s2[@"stationName"]];
    }];
    [mutableCategories addObject:[mutableCategory copy]];
  }
  genreResults = [mutableCategories copy];
  [genres reloadData];
  [genreSpinner stopAnimation:nil];
  [genreSpinner setHidden:YES];
}

#pragma mark - Callbacks for IBActions and such

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
  [[self pandora] fetchGenreStations];
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

  if (![item isKindOfClass:[PandoraSearchResult class]]) {
    [errorIndicator setHidden:NO];
    return;
  }

  PandoraSearchResult *result = item;

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

/* Callback for the delete button on the stations drawer */
- (IBAction)deleteSelected: (id)sender {
  Station *selected = [self selectedStation];

  if (selected == nil || selected.isQuickMix) {
    return;
  }

  NSAlert *alert = [NSAlert new];
  alert.messageText = [NSString stringWithFormat:@"Are you sure you want to permanently delete the station “%@”?", selected.name];
  [alert addButtonWithTitle:@"Cancel"];
  [alert addButtonWithTitle:@"Delete"];
  alert.alertStyle = NSWarningAlertStyle;
  alert.icon = [NSImage imageNamed:@"error_icon"];

  [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse returnCode) {
    if (returnCode != NSAlertSecondButtonReturn) // Delete (non-default)
      return;
    
    if ([selected isEqual:[self playingStation]]) {
      HermesAppDelegate *delegate = [NSApp delegate];
      [[delegate playback] playStation:nil];
      [delegate setCurrentView:chooseStationView];
    }
    
    [stationsRefreshing setHidden:NO];
    [stationsRefreshing startAnimation:nil];
    [[self pandora] removeStation:[selected token]];
  }];
}

- (IBAction)editSelected:(id)sender {
  Station *s = [self selectedStation];
  if (s == nil || s.isQuickMix) return;
  StationController *c = [(HermesAppDelegate*)[NSApp delegate] station];
  [c editStation:s];
}

- (IBAction) toggleSort:(id)sender {
  NSInteger cur = PREF_KEY_INT(SORT_STATIONS);
  NSInteger otherSegment = SORT_NAME;
  BOOL isAscending = NO;
  switch ([sender selectedSegment]) {
    case SORT_NAME:
      cur = (cur == SORT_NAME_ASC) ? SORT_NAME_DSC : SORT_NAME_ASC;
      isAscending = (cur == SORT_NAME_ASC);
      otherSegment = SORT_DATE;
      break;
    case SORT_DATE:
      cur = (cur == SORT_DATE_ASC) ? SORT_DATE_DSC : SORT_DATE_ASC;
      otherSegment = SORT_NAME;
      isAscending = (cur == SORT_DATE_ASC);
      break;
  }
  PREF_KEY_SET_INT(SORT_STATIONS, cur);
  [sender setImage:nil forSegment:otherSegment];
  [sender setImage:
   [NSImage imageNamed:isAscending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"] forSegment:[sender selectedSegment]];
  [self sortStations];
  [stationsTable reloadData];
}

@end
