#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "Pandora.h"
#import "Station.h"

@interface StationsController : NSObject <NSTableViewDataSource, NSOutlineViewDataSource> {

  IBOutlet NSView *view;

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
}

- (void) showDrawer;
- (void) hideDrawer;
- (void) show;
- (void) reset;

// Buttons at bottom of drawer
- (IBAction)deleteSelected: (id)sender;
- (IBAction)playSelected: (id)sender;
- (IBAction)refreshList: (id)sender;
- (IBAction)addStation: (id)sender;

// Actions from new station sheet
- (IBAction)search: (id)sender;
- (IBAction)cancelCreateStation: (id)sender;
- (IBAction)createStation: (id)sender;

@end
