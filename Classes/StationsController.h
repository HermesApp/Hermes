#define LAST_STATION_KEY @"hermes.last-station"

@class FileReader;
@class Station;

@interface StationsController : NSObject <NSTableViewDataSource, NSOutlineViewDataSource> {

  IBOutlet NSView *view;

  IBOutlet NSButton *showStations;
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

  FileReader *reader;
}

- (void) showDrawer;
- (void) hideDrawer;
- (IBAction) toggleDrawer: (id) sender;
- (void) show;
- (void) reset;

// Buttons at bottom of drawer
- (IBAction)deleteSelected: (id)sender;
- (IBAction)playSelected: (id)sender;
- (IBAction)editSelected: (id)sender;
- (IBAction)refreshList: (id)sender;
- (IBAction)addStation: (id)sender;

// Actions from new station sheet
- (IBAction)search: (id)sender;
- (IBAction)cancelCreateStation: (id)sender;
- (IBAction)createStation: (id)sender;

- (int) stationIndex: (Station*) station;

@end
