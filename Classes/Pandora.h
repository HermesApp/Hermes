@class Station;

#import "Song.h"
#import "API.h"

#define PARTNER_USERNAME @"iphone"
#define PARTNER_PASSWORD @"P2E4FC0EAD3*878N92B2CDp34I0B1@388137C"
#define PARTNER_DEVICEID @"IP01"
#define PARTNER_DECRYPT  "20zE1E47BE57$51"
#define PARTNER_ENCRYPT  "721^26xE22776"

typedef void(^SyncCallback)(void);

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
  NSMutableArray *stations;
  int retries;

  NSString *partner_id;
  NSString *partner_auth_token;
  NSString *user_auth_token;
  NSString *user_id;
  uint64_t sync_time;
  uint64_t start_time;
}

@property (retain) NSArray* stations;

- (BOOL) authenticate: (NSString*)user :(NSString*)pass :(PandoraRequest*)req;
- (BOOL) fetchStations;
- (BOOL) getFragment: (Station*)station;
- (BOOL) partnerLogin: (SyncCallback) cb;
- (BOOL) rateSong:(Song*) song as:(BOOL) liked;
- (BOOL) tiredOfSong: (Song*)song;
- (BOOL) search: (NSString*) search;
- (BOOL) createStation: (NSString*) musicId;
- (BOOL) removeStation: (NSString*) stationToken;
- (BOOL) renameStation: (NSString*)stationToken to:(NSString*)name;
- (void) logout;

@end
