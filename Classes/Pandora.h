#import "Song.h"
#import "API.h"

/* Wrapper for search results */
@interface SearchResult : NSObject {
  NSString *name;
  NSString *value;
}

@property (retain) NSString *name;
@property (retain) NSString *value;

@end

/* Implementation of Pandora's API */
@interface Pandora : API {
  NSString *authToken;
  NSMutableArray *stations;
  int retries;
}

@property (retain) NSString* authToken;
@property (retain) NSArray* stations;

- (BOOL) authenticate: (NSString*)user :(NSString*)pass;
- (BOOL) fetchStations;
- (BOOL) getFragment: (NSString*)station_id;
- (BOOL) sync;
- (BOOL) rateSong: (Song*)song : (NSString*)rating;
- (BOOL) tiredOfSong: (Song*)song;
- (BOOL) search: (NSString*) search;
- (BOOL) createStation: (NSString*) musicId;
- (BOOL) removeStation: (NSString*) stationId;
- (BOOL) renameStation: (NSString*)stationId to:(NSString*)name;
- (void) logout;

@end
