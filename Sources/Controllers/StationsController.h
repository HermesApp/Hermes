#define LAST_STATION_KEY @"hermes.last-station"

@class FileReader;
@class Station;

@interface StationsController : NSObject <NSTableViewDataSource, NSOutlineViewDataSource> {

  IBOutlet NSView *chooseStationView;

  IBOutlet NSDrawer *stations;
  IBOutlet NSTableView *stationsTable;
  IBOutlet NSProgressIndicator *stationsRefreshing;

  IBOutlet NSButton *playStationButton;
  IBOutlet NSButton *deleteStationButton;
  IBOutlet NSButton *editStationButton;

  /* New station by searching */
  IBOutlet NSTextField *search;
  IBOutlet NSOutlineView *results;
  IBOutlet NSProgressIndicator *searchSpinner;
  IBOutlet NSImageView *errorIndicator;

  /* New station by genres */
  IBOutlet NSOutlineView *genres;
  IBOutlet NSProgressIndicator *genreSpinner;

  /* Last known results */
  NSDictionary *lastResults;
  NSArray *genreResults;

  /* Sorting the station list */
  IBOutlet NSSegmentedControl *sort;

  FileReader *reader;
}

- (void) showDrawer;
- (void) hideDrawer;
- (void) show;
- (void) reset;
- (void) focus;

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
- (IBAction)createStationGenre: (id)sender;

- (int) stationIndex: (Station*) station;

@end
