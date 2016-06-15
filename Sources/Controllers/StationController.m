/**
 * @file StationController.m
 * @brief Implementation of editing stations
 */

#import "HermesAppDelegate.h"
#import "ImageLoader.h"
#import "Pandora/Station.h"
#import "StationController.h"
#import "Notifications.h"

@implementation StationController

- (void) showSpinner {
  [progress setHidden:FALSE];
  [progress startAnimation:nil];
}

- (void) hideSpinner {
  [progress setHidden:TRUE];
  [progress stopAnimation:nil];
}

- (id) init {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self
             selector:@selector(stationInfo:)
                 name:PandoraDidLoadStationInfoNotification
               object:nil];
  [center addObserver:self
             selector:@selector(hideSpinner)
                 name:PandoraDidRenameStationNotification
               object:nil];
  [center addObserver:self
             selector:@selector(feedbackDeleted:)
                 name:PandoraDidDeleteFeedbackNotification
               object:nil];
  [center addObserver:self
             selector:@selector(searchCompleted:)
                 name:PandoraDidLoadSearchResultsNotification
               object:nil];
  [center addObserver:self
             selector:@selector(seedAdded:)
                 name:PandoraDidAddSeedNotification
               object:nil];
  [center addObserver:self
             selector:@selector(seedDeleted:)
                 name:PandoraDidDeleteSeedNotification
               object:nil];
  [center addObserver:self
             selector:@selector(stationRemoved:)
                 name:PandoraDidDeleteStationNotification
               object:nil];
  [center addObserver:self
             selector:@selector(songRated:)
                 name:PandoraDidRateSongNotification
               object:nil];
  return [super init];
}

/**
 * @brief Begin editing a station by displaying all the necessary dialogs
 *
 * @param station the station to edit (nil to close editor, e.g. if station is deleted)
 */
- (void) editStation: (Station*) station {
  [stationName setEnabled:FALSE];
  [stationName setStringValue:@""];
  [stationCreated setStringValue:@""];
  [stationGenres setStringValue:@""];
  [art setImage:nil];
  if (station != nil) {
    [progress setHidden:FALSE];
    [progress startAnimation:nil];
    [[[NSApp delegate] pandora] fetchStationInfo: station];
  }
  cur_station = station;
  station_url = nil;

  [seedAdd setEnabled:FALSE];
  [seedDel setEnabled:FALSE];
  [deleteFeedback setEnabled:FALSE];
  alikes = adislikes = nil;
  [likes reloadData];
  [dislikes reloadData];
  [seedSearch setStringValue:@""];
  seeds = nil;
  lastResults = nil;
  [seedsCurrent reloadData];
  [seedsResults reloadData];
  if (station == nil) {
    [window orderOut:nil];
  } else {
    [self showSpinner];
    [window makeKeyAndOrderFront:nil];
  }
}

- (NSArray *)formattedArray:(NSArray *)alikesDislikes forLikesOrDislikes:(NSTableView *)likesDislikes {
  NSMutableArray *formattedArray = [[NSMutableArray alloc] initWithCapacity:alikesDislikes.count];
  for (NSDictionary *likeDislike in alikesDislikes) {
    NSMutableDictionary *likeDislikeFormatted = [likeDislike mutableCopy];
    likeDislikeFormatted[@"name"] = [NSString stringWithFormat:@"%@ - %@",
                                     likeDislikeFormatted[@"artistName"],
                                     likeDislikeFormatted[@"songName"]];
    [formattedArray addObject:likeDislikeFormatted];
  }
  return [formattedArray sortedArrayUsingDescriptors:likesDislikes.sortDescriptors];
}

/**
 * @brief Callback invoked when a station's info arrives
 *
 * This actually sets up the GUI and prepares everything for editing
 */
- (void) stationInfo: (NSNotification*) notification {
  NSDictionary *info = [notification userInfo];
  [progress setHidden:TRUE];
  [progress stopAnimation:nil];

  station_url = info[@"url"];
  if ([cur_station allowRename]) {
    [stationName setEnabled:TRUE];
    [stationName setToolTip:@"Change the station's name"];
  } else {
    [stationName setEnabled:FALSE];
    [stationName setToolTip:@"Not allowed to change the station's name"];
  }
  [stationName setStringValue:info[@"name"]];
  NSArray *genres = info[@"genres"];
  [stationGenres setStringValue:[genres componentsJoinedByString:@", "]];
  [stationCreated setStringValue:
    [NSDateFormatter localizedStringFromDate:info[@"created"]
                                   dateStyle:NSDateFormatterShortStyle
                                   timeStyle:NSDateFormatterNoStyle]];
  if (info[@"art"] != nil) {
    [[ImageLoader loader] loadImageURL:info[@"art"]
                              callback:^(NSData* data) {
      NSImage *image = [[NSImage alloc] initWithData:data];
      if (image == nil) {
        image = [NSImage imageNamed:@"missing-album"];
      }
      [art setImage:image];
    }];
  } else {
    [art setImage:[NSImage imageNamed:@"missing-album"]];
  }

  alikes = [self formattedArray:info[@"likes"] forLikesOrDislikes:likes];
  adislikes = [self formattedArray:info[@"dislikes"] forLikesOrDislikes:dislikes];
  [deleteFeedback setEnabled:TRUE];
  seeds = info[@"seeds"];
  [likes reloadData];
  [dislikes reloadData];
  [likes setEnabled:YES];
  [dislikes setEnabled:YES];
  [seedsCurrent reloadData];
  [seedsResults reloadData];
  [seedsCurrent expandItem:@"songs"];
  [seedsCurrent expandItem:@"artists"];
}

- (IBAction) renameStation:(id)sender {
  Pandora *pandora = [[NSApp delegate] pandora];
  [pandora renameStation:[cur_station token] to:[stationName stringValue]];
  [cur_station setName:[stationName stringValue]];
  [self showSpinner];
}

- (IBAction) gotoPandora:(id)sender {
  NSURL *url = [NSURL URLWithString:station_url];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (NSDictionary *)seedsWithNoEmptyKinds:(NSDictionary *)seedDictionary {
  NSMutableDictionary *mutableSeeds = [seedDictionary mutableCopy];
  for (NSString *seedKind in [mutableSeeds allKeys]) {
    if ([mutableSeeds[seedKind] count] == 0)
      [mutableSeeds removeObjectForKey:seedKind];
  }
  return [mutableSeeds copy];
}

- (void)stationRemoved:(NSNotification *)notification {
  if ([notification object] == cur_station)
    [self editStation:nil];
}

#pragma mark - Search for a seed

- (IBAction) searchSeeds:(id)sender {
  Pandora *pandora = [[NSApp delegate] pandora];
  [self showSpinner];
  [pandora search:[seedSearch stringValue]];
}

- (void) searchCompleted:(NSNotification*) not {
  if (![not.object isEqualToString:[seedSearch stringValue]])
    return;
  lastResults = [self seedsWithNoEmptyKinds:[not userInfo]];
  [seedsResults deselectAll:nil];
  [seedsResults reloadData];
  for (NSString *category in [lastResults allKeys])
    [seedsResults expandItem:category];
  [self hideSpinner];
}

#pragma mark - Adding a seed

- (IBAction) addSeed:(id)sender {
  // XXX doesn't fully implement adding multiple seeds (particularly, there's no support for handling errors)
  // XXX - multiple selection is disabled in IB for this reason
  NSIndexSet *set = [seedsResults selectedRowIndexes];
  if ([set count] == 0) return;
  Pandora *pandora = [[NSApp delegate] pandora];

  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    id item = [seedsResults itemAtRow:idx];
    if (![item isKindOfClass:[PandoraSearchResult class]]) {
      return;
    }
    PandoraSearchResult *d = item;
    [pandora addSeed:[d value] toStation:cur_station];
    [self showSpinner];
  }];
  [seedsResults deselectAll:nil];
}

- (void) seedAdded:(NSNotification*) not {
  [self hideSpinner];
  NSDictionary *seed = [not userInfo];
  NSString *seedKind = (seed[@"songName"] == nil) ? @"artists" : @"songs";
  NSMutableArray *seedsOfKind = seeds[seedKind];
  if (seedsOfKind == nil) {
    seedsOfKind = seeds[seedKind] = [NSMutableArray array];
  }
  [seedsOfKind addObject:seed];
  seeds[seedKind] = seedsOfKind;
  [seedsCurrent reloadData];
  [seedsCurrent expandItem:seedKind];
}

#pragma mark - Delete a seed

- (IBAction) deleteSeed:(id)sender {
  // XXX doesn't fully implement deleting multiple seeds (particularly, there's no support for handling errors)
  // XXX - multiple selection is disabled in IB for this reason
  NSIndexSet *set = [seedsCurrent selectedRowIndexes];
  if ([set count] == 0) return;
  Pandora *pandora = [[NSApp delegate] pandora];
  __block int removeRequests = 0;

  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    id item = [seedsCurrent itemAtRow:idx];
    if (![item isKindOfClass:[NSDictionary class]]) {
      return;
    }
    NSDictionary *d = item;
    [pandora removeSeed:d[@"seedId"]];
    removeRequests++;
  }];

  if (removeRequests == 0) {
    return;
  }
  [self showSpinner];
  [seedsCurrent setEnabled:FALSE];
  [deleteFeedback setEnabled:FALSE];
}

- (void) seedDeleted:(NSNotification*) not {
  // XXX doesn't fully implement deleting multiple seeds (particularly, there's no path for error handling)
  // XXX - multiple selection is disabled in IB for this reason
  // XXX however, the same seed can be added more than once, so we may actually delete multiple items even in this case
  [self hideSpinner];
  NSIndexSet *set = [seedsCurrent selectedRowIndexes];
  if ([set count] == 0) return;

  NSMutableSet *seedIdsToDelete = [NSMutableSet set];
  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    id item = [seedsCurrent itemAtRow:idx];
    if ([item isKindOfClass:[NSDictionary class]]) {
      [seedIdsToDelete addObject:item[@"seedId"]];
    }
  }];

  for (NSString *seedKind in seeds) {
    NSMutableArray *seedsOfKind = seeds[seedKind];
    NSIndexSet *seedIndexesToDelete = [seedsOfKind indexesOfObjectsPassingTest:^BOOL(id _Nonnull seed, NSUInteger idx, BOOL * _Nonnull stop) {
      return [seedIdsToDelete containsObject:seed[@"seedId"]];
    }];
    if (seedIndexesToDelete.count == 0)
      continue;
    [seedsOfKind removeObjectsAtIndexes:seedIndexesToDelete];
  }
  seeds = [[self seedsWithNoEmptyKinds:seeds] mutableCopy];

  [seedsCurrent deselectAll:nil];
  [seedsCurrent reloadData];

  [seedsCurrent setEnabled:TRUE];
  [deleteFeedback setEnabled:TRUE];
}

- (void) seedFailedDeletion:(NSNotification*) not {
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Cannot delete all seeds from a station";
  alert.informativeText = @"A station must always contain at least one seed.";
  alert.alertStyle = NSWarningAlertStyle;
  alert.icon = [NSImage imageNamed:@"error_icon"];
  [alert beginSheetModalForWindow:window completionHandler:nil];

  [self hideSpinner];
  [seedsCurrent setEnabled:TRUE];
  [seedsCurrent becomeFirstResponder];
  [deleteFeedback setEnabled:TRUE];
}

#pragma mark - Add feedback
- (void)songRated:(NSNotification *)notification {
  Song *song = [notification object];
  if ([song.stationId isEqualToString:cur_station.stationId]) {
    [likes setEnabled:NO];
    [dislikes setEnabled:NO];
    [progress setHidden:FALSE];
    [progress startAnimation:nil];
    [[[NSApp delegate] pandora] fetchStationInfo:cur_station];
  }
}

#pragma mark - Delete feedback

- (void)delfeed:(NSArray*)feed table:(NSTableView*)view {
  NSIndexSet *set = [view selectedRowIndexes];
  if ([set count] == 0)
    return;

  Pandora *pandora = [[NSApp delegate] pandora];
  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    NSDictionary *song = feed[idx];
    [pandora deleteFeedback:song[@"feedbackId"]];
  }];
}

- (IBAction) deleteFeedback:(id)sender {
  [self showSpinner];
  [self delfeed:alikes table:likes];
  [self delfeed:adislikes table:dislikes];
}

- (NSArray *)arrayRemovingFeedbackId:(NSString *)feedbackId fromArray:(NSArray *)array inTableView:(NSTableView *)tableView {
  NSUInteger indexOfFeedback = [array indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    return [obj[@"feedbackId"] isEqualToString:feedbackId];
  }];
  if (indexOfFeedback == NSNotFound)
    return array;
  NSMutableArray *mutableArray = [array mutableCopy];
  [mutableArray removeObjectAtIndex:indexOfFeedback];
  [tableView reloadData];
  [tableView deselectAll:nil];
  return [mutableArray copy];
}

- (void)feedbackDeleted:(NSNotification *)notification {
  NSString *feedbackId = [notification object];
  alikes = [self arrayRemovingFeedbackId:feedbackId fromArray:alikes inTableView:likes];
  adislikes = [self arrayRemovingFeedbackId:feedbackId fromArray:adislikes inTableView:dislikes];
  [self hideSpinner];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  if (aTableView == likes) {
    return [alikes count];
  } else {
    return [adislikes count];
  }
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex {

  NSArray *arr = aTableView == likes ? alikes : adislikes;

  if ((NSUInteger) rowIndex >= [arr count]) { return nil; }
  return arr[rowIndex][@"name"];
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  NSArray *newDescriptors = aTableView.sortDescriptors;
  if (newDescriptors.count == 0)
    return;
  
  // tri-state sort — ascending name/descending name/descending date (default as returned from Pandora)
  if (oldDescriptors.count > 0) {
    NSSortDescriptor *oldDescriptor = oldDescriptors[0];
    if ([oldDescriptor.key isEqualToString:@"name"] && !oldDescriptor.ascending) {
      [aTableView setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated.time" ascending:NO selector:@selector(compare:)]]];
      return;
    }
  }
  
  if (aTableView == likes) {
    alikes = [alikes sortedArrayUsingDescriptors:newDescriptors];
  } else {
    adislikes = [adislikes sortedArrayUsingDescriptors:newDescriptors];
  }
  [aTableView reloadData];
}

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification {
  if ([aNotification object] == likes) {
    [dislikes deselectAll:nil];
  } else {
    [likes deselectAll:nil];
  }
}

#pragma mark - NSOutlineViewDataSource
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  NSDictionary *d = outlineView == seedsCurrent ? seeds : lastResults;
  if (item == nil) {
    return [[d allKeys] sortedArrayUsingSelector:@selector(compare:)][index];
  }
  return d[item][index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  NSDictionary *d = outlineView == seedsCurrent ? seeds : lastResults;
  return d[item] != nil;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  NSDictionary *d = outlineView == seedsCurrent ? seeds : lastResults;
  if (item == nil) {
    return [[d allKeys] count];
  }
  return [d[item] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
  objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
  if ([item isKindOfClass:[NSString class]]) {
    return [item capitalizedString];
  }

  if (outlineView == seedsResults) {
    PandoraSearchResult *result = item;
    return [result name];
  }

  NSDictionary *i = item;
  NSString *artist = i[@"artistName"];
  NSString *song   = i[@"songName"];
  if (song == nil) {
    return artist;
  }
  return [NSString stringWithFormat:@"%@ - %@", song, artist];
}

#pragma mark - NSOutlineViewDelegate
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
  return [item isKindOfClass:[NSString class]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
  return ![item isKindOfClass:[NSString class]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
  NSOutlineView *outlineView = [notification object];
  NSButton *button = nil;
  if (outlineView == seedsResults)
    button = seedAdd;
  else if (outlineView == seedsCurrent)
    button = seedDel;
  [button setEnabled:([outlineView numberOfSelectedRows] > 0)];
}

@end
