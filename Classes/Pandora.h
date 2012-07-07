@class Station;

#import "Pandora/API.h"
#import "Pandora/Song.h"

#define PARTNER_USERNAME @"iphone"
#define PARTNER_PASSWORD @"P2E4FC0EAD3*878N92B2CDp34I0B1@388137C"
#define PARTNER_DEVICEID @"IP01"
#define PARTNER_DECRYPT  "20zE1E47BE57$51"
#define PARTNER_ENCRYPT  "721^26xE22776"

#define INVALID_AUTH_TOKEN    1001
#define INVALID_PARTNER_LOGIN 1002
#define INVALID_USERNAME      1011
#define INVALID_PASSWORD      1012
#define NO_SEEDS_LEFT         1032

typedef void(^SyncCallback)(void);

/* Wrapper for search results */
@interface SearchResult : NSObject

@property NSString *name;
@property NSString *value;

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

@property (readonly) NSArray* stations;

- (BOOL) authenticate:(NSString*)user
             password:(NSString*)password
              request:(PandoraRequest*)req;
- (BOOL) fetchStations;
- (BOOL) getFragment: (Station*)station;
- (BOOL) partnerLogin: (SyncCallback) cb;
- (BOOL) rateSong:(Song*) song as:(BOOL) liked;
- (BOOL) tiredOfSong: (Song*)song;
- (BOOL) search: (NSString*) search;
- (BOOL) createStation: (NSString*) musicId;
- (BOOL) removeStation: (NSString*) stationToken;
- (BOOL) renameStation: (NSString*)stationToken to:(NSString*)name;
- (BOOL) stationInfo: (Station*) station;
- (BOOL) deleteFeedback: (NSString*)feedbackId;
- (BOOL) addSeed: (NSString*)token to:(Station*)station;
- (BOOL) removeSeed: (NSString*)seedId;
- (BOOL) genreStations;
- (void) logout;
- (void) logoutNoNotify;

+ (NSString*) errorString: (int) code;

@end
