/**
 * @file StationController.h
 * @brief Headers for editing stations
 */

@class Station;
@class ImageLoader;

@interface StationController : NSObject <NSTableViewDataSource, NSOutlineViewDataSource> {
  IBOutlet NSWindow *window;

  /* Metadata */
  IBOutlet NSImageView *art;
  IBOutlet NSTextField *stationName;
  IBOutlet NSTextField *stationCreated;
  IBOutlet NSTextField *stationGenres;
  IBOutlet NSProgressIndicator *progress;
  IBOutlet NSButton *gotoStation;

  /* Seeds */
  IBOutlet NSTextField *seedSearch;
  IBOutlet NSOutlineView *seedsResults;
  IBOutlet NSOutlineView *seedsCurrent;
  NSDictionary *seeds;
  NSDictionary *lastResults;
  IBOutlet NSButton *seedAdd;
  IBOutlet NSButton *seedDel;

  /* Likes/Dislikes */
  IBOutlet NSTableView *likes;
  IBOutlet NSTableView *dislikes;
  NSArray *alikes;
  NSArray *adislikes;
  IBOutlet NSButton *deleteFeedback;

  Station *cur_station;
  ImageLoader *loader;
  NSString *station_url;
}

- (void) editStation: (Station*) station;
- (IBAction) renameStation:(id)sender;
- (IBAction) gotoPandora:(id)sender;

- (IBAction) searchSeeds:(id)sender;
- (IBAction) addSeed:(id)sender;
- (IBAction) deleteSeed:(id)sender;
- (void) seedFailedDeletion:(NSNotification*) not;

- (IBAction) deleteFeedback:(id)sender;

@end
