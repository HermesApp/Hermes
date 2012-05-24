#import "Pandora.h"
#import "Crypt.h"
#import "Station.h"
#import "Song.h"
#import "HermesAppDelegate.h"

@implementation SearchResult

@synthesize value, name;

@end

static NSString *lowerrs[] = {
  [0] = @"Internal Pandora error",
  [1] = @"Pandora is in Maintenance Mode",
  [2] = @"URL is missing method parameter",
  [3] = @"URL is missing auth token",
  [4] = @"URL is missing partner ID",
  [5] = @"URL is missing user ID",
  [6] = @"A secure protocol is required for this request",
  [7] = @"A certificate is required for the request",
  [8] = @"Paramter type mismatch",
  [9] = @"Parameter is missing",
  [10] = @"Parameter value is invalid",
  [11] = @"API version is not supported",
  [12] = @"Pandora is not available in this country",
  [13] = @"Bad sync time",
  [14] = @"Unknown method name",
  [15] = @"Wrong protocol used"
};

static NSString *hierrs[] = {
  [0] = @"Read only mode",
  [1] = @"Invalid authentication token",
  [2] = @"Invalid partner login",
  [3] = @"Listener not authorized",
  [4] = @"User not authorized",
  [5] = @"Station limit reached",
  [6] = @"Station does not exist",
  [7] = @"Complimentary period already in use",
  [8] = @"Call not allowed",
  [9] = @"Device not found",
  [10] = @"Partner not authorized",
  [11] = @"Invalid username",
  [12] = @"Invalid password",
  [13] = @"Username already exists",
  [14] = @"Device already associated to account",
  [15] = @"Upgrade, device model is invalid",
  [18] = @"Explicit PIN incorrect",
  [20] = @"Explicit PIN malformed",
  [23] = @"Device model invalid",
  [24] = @"ZIP code invalid",
  [25] = @"Birth year invalid",
  [26] = @"Birth year too young",
  [27] = @"Invalid country code",
  [28] = @"Invalid gender",
  [32] = @"Cannot remove all seeds",
  [34] = @"Device disabled",
  [35] = @"Daily trial limit reached",
  [36] = @"Invalid sponsor",
  [37] = @"User already used trial"
};

@implementation Pandora

@synthesize stations;

+ (NSString*) errorString: (int) code {
  if (code < 16) {
    return lowerrs[code];
  } else if (code >= 1000 && code <= 1037) {
    return hierrs[code - 1000];
  }
  return nil;
}

- (id) init {
  if ((self = [super init])) {
    stations = [[NSMutableArray alloc] init];
    retries  = 0;
  }
  return self;
}

- (void) notify: (NSString*)msg with:(NSDictionary*)obj {
  [[NSNotificationCenter defaultCenter] postNotificationName:msg object:self
      userInfo:obj];
}

- (void) logout {
  [self logoutNoNotify];
  [self notify: @"hermes.logged-out" with:nil];
}

- (void) logoutNoNotify {
  [stations removeAllObjects];
  user_auth_token = nil;
  partner_auth_token = nil;
  partner_id = nil;
  user_id = nil;
  sync_time = start_time = 0;
}

- (BOOL) authenticated {
  return user_auth_token != nil;
}

- (NSNumber*) syncTimeNum {
  return [NSNumber numberWithLongLong: sync_time + ([self time] - start_time)];
}

/**
 * @brief Creates a dictionary which contains the default keys necessary for
 *        most requests
 *
 * Currently fills in the "userAuthToken" and "syncTime" fields
 */
- (NSMutableDictionary*) defaultDictionary {
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  [d setObject:user_auth_token forKey:@"userAuthToken"];
  [d setObject:[self syncTimeNum] forKey:@"syncTime"];
  return d;
}

/**
 * @brief Create the default request, with appropriate fields set based on the
 *        current state of authentication
 *
 * @param method the method name for the request to be for
 * @return the PandoraRequest object to further add callbacks to
 */
- (PandoraRequest*) defaultRequest: (NSString*) method {
  PandoraRequest *req = [[PandoraRequest alloc] init];
  [req setUserId:user_id];
  [req setAuthToken:user_auth_token];
  [req setMethod:method];
  [req setPartnerId:partner_id];
  return req;
}

/**
 * @brief Parse the dictionary provided to create a station
 *
 * @param s the dictionary describing the station
 * @return the station object
 */
- (Station*) parseStation: (NSDictionary*) s {
  Station *station = [[Station alloc] init];

  [station setName:[s objectForKey:@"stationName"]];
  [station setStationId:[s objectForKey:@"stationId"]];
  [station setToken:[s objectForKey:@"stationToken"]];
  [station setRadio:self];

  if ([[s objectForKey:@"isQuickMix"] boolValue]) {
    [station setName:@"QuickMix"];
  }
  return station;
}

/**
 * @brief Authenticates with Pandora
 *
 * When completed, fires the "hermes.authenticated" event so long as the
 * provided request to retry is nil.
 *
 * @param user the username to log in with
 * @param pass the password to log in with
 * @param req an optional request which will be retried once the authentication
 *        has completed
 */
- (BOOL) authenticate:(NSString*)user :(NSString*)pass :(PandoraRequest*)req {
  if (partner_id == nil) {
    return [self partnerLogin: ^() {
      [self authenticate: user : pass : req];
    }];
  }

  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  [d setObject: @"user"            forKey: @"loginType"];
  [d setObject: user               forKey: @"username"];
  [d setObject: pass               forKey: @"password"];
  [d setObject: partner_auth_token forKey: @"partnerAuthToken"];
  [d setObject: [self syncTimeNum] forKey: @"syncTime"];

  PandoraRequest *r = [[PandoraRequest alloc] init];
  [r setRequest: d];
  [r setMethod: @"auth.userLogin"];
  [r setPartnerId: partner_id];
  [r setAuthToken: partner_auth_token];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = [dict objectForKey:@"result"];
    user_auth_token = [result objectForKey:@"userAuthToken"];
    user_id = [result objectForKey:@"userId"];

    if (req == nil) {
      [self notify:@"hermes.authenticated" with:nil];
    } else {
      NSLogd(@"Retrying request...");
      [req setResponse:[[NSMutableData alloc] init]];
      [[req request] setObject: user_auth_token forKey:@"userAuthToken"];
      [self sendRequest:req];
    }
  }];
  return [self sendRequest:r];
}

/**
 * @brief Fetches a list of stations for the logged in user
 *
 * Fires the "hermes.stations" event with no extra information. All of the
 * stations found are stored internally in this Pandora object.
 */
- (BOOL) fetchStations {
  assert([self authenticated]);
  NSLogd(@"Fetching stations...");

  NSMutableDictionary *d = [self defaultDictionary];

  PandoraRequest *r = [self defaultRequest:@"user.getStationList"];
  [r setRequest:d];
  [r setTls:FALSE];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = [dict objectForKey:@"result"];
    for (NSDictionary *s in [result objectForKey:@"stations"]) {
      Station *station = [self parseStation:s];
      if (![stations containsObject:station]) {
        [stations addObject:station];
      }
    };

    [self notify:@"hermes.stations" with:nil];
  }];

  return [self sendRequest:r];
}

/**
 * @brief Get a small list of songs for a station
 *
 * Fires the "hermes.fragment-fetched.XX" where XX is replaced by the station
 * token. The userInfo for the notification has one key, "songs", which contains
 * an array of Song objects describing the next songs for the station
 *
 * @param station the station to fetch more songs for
 */
- (BOOL) getFragment: (Station*) station {
  assert([self authenticated]);
  NSLogd(@"Getting fragment for %@...", [station name]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:[station token] forKey:@"stationToken"];
  [d setObject:@"HTTP_32_AACPLUS_ADTS,HTTP_64_AACPLUS_ADTS,HTTP_192_MP3"
        forKey:@"additionalAudioUrl"];

  PandoraRequest *r = [self defaultRequest:@"station.getPlaylist"];
  [r setRequest:d];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = [dict objectForKey:@"result"];
    NSMutableArray *songs = [NSMutableArray array];

    for (NSDictionary *s in [result objectForKey:@"items"]) {
      if ([s objectForKey:@"adToken"] != nil) continue; // Skip if this is an adToken

      Song *song = [[Song alloc] init];

      [song setArtist: [s objectForKey:@"artistName"]];
      [song setTitle: [s objectForKey:@"songName"]];
      [song setAlbum: [s objectForKey:@"albumName"]];
      [song setArt: [s objectForKey:@"albumArtUrl"]];
      [song setStationId: [s objectForKey:@"stationId"]];
      [song setToken: [s objectForKey:@"trackToken"]];
      [song setNrating: [s objectForKey:@"songRating"]];
      [song setAlbumUrl: [s objectForKey:@"albumDetailUrl"]];
      [song setArtistUrl: [s objectForKey:@"artistDetailUrl"]];
      [song setTitleUrl: [s objectForKey:@"songDetailUrl"]];
      [song setStationToken:[station token]];

      NSArray *urls = [s objectForKey:@"additionalAudioUrl"];
      [song setLowUrl:[urls objectAtIndex:0]];
      [song setMedUrl:[urls objectAtIndex:1]];
      [song setHighUrl:[urls objectAtIndex:2]];

      [songs addObject: song];
    };

    NSString *name = [NSString stringWithFormat:@"hermes.fragment-fetched.%@",
                        [station token]];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:songs forKey:@"songs"];
    [self notify:name with:d];
  }];

  return [self sendRequest:r];
}

/**
 * @brief Log in the "partner" with Pandora
 *
 * Retrieves the sync time and the partner auth token.
 *
 * @param callback a callback to be invoked once the synchronization and login
 *        is done
 */
- (BOOL) partnerLogin: (SyncCallback) callback {
  start_time = [self time];
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  [d setObject:PARTNER_USERNAME forKey:@"username"];
  [d setObject:PARTNER_PASSWORD forKey:@"password"];
  [d setObject:PARTNER_DEVICEID forKey:@"deviceModel"];
  [d setObject:PANDORA_API_VERSION forKey:@"version"];
  [d setObject:[NSNumber numberWithBool:TRUE] forKey:@"includeUrls"];

  PandoraRequest *req = [[PandoraRequest alloc] init];
  [req setRequest: d];
  [req setMethod: @"auth.partnerLogin"];
  [req setEncrypted:FALSE];
  [req setCallback:^(NSDictionary* dict) {
    NSDictionary *result = [dict objectForKey:@"result"];
    partner_auth_token = [result objectForKey:@"partnerAuthToken"];
    partner_id = [result objectForKey:@"partnerId"];
    NSData *sync = PandoraDecrypt([result objectForKey:@"syncTime"]);
    const char *bytes = [sync bytes];
    sync_time = strtoul(bytes + 4, NULL, 10);
    callback();
  }];
  return [self sendRequest:req];
}

/**
 * @param Rate a Song
 *
 * Fires the "hermes.song-rated" event when done. The userInfo for the event is
 * a dictionary with one key, "song", the same one as provided to this method
 *
 * @param song the song to add a rating for
 * @param liked the rating to give the song, TRUE for liked or FALSE for
 *        disliked
 */
- (BOOL) rateSong:(Song*) song as:(BOOL) liked {
  assert([self authenticated]);
  NSLogd(@"Rating song '%@' as %d...", [song title], liked);

  if (liked == TRUE) {
    [song setNrating:[NSNumber numberWithInt:1]];
  } else {
    [song setNrating:[NSNumber numberWithInt:-1]];
  }

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:[song token] forKey:@"trackToken"];
  [d setObject:[NSNumber numberWithBool:liked] forKey:@"isPositive"];
  [d setObject:[song stationToken] forKey:@"stationToken"];

  PandoraRequest *req = [self defaultRequest:@"station.addFeedback"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* _) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:song forKey:@"song"];
    [self notify:@"hermes.song-rated" with:dict];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Inform Pandora that the specified song shouldn't be played for awhile
 *
 * Fires the "hermes.song-tired" event with a dictionary with the key "song"
 * when the event is done. The song of the event is the same one as provided
 * here.
 *
 * @param song the song to tell Pandora not to play for awhile
 */
- (BOOL) tiredOfSong: (Song*) song {
  assert([self authenticated]);
  NSLogd(@"Getting tired of %@...", [song title]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:[song token] forKey:@"trackToken"];

  PandoraRequest *req = [self defaultRequest:@"user.sleepSong"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* _) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:song forKey:@"song"];
    [self notify:@"hermes.song-tired" with:dict];
  }];

  return [self sendRequest:req];
}

/**
 * @brief Searches for Songs
 *
 * Fires the "hermes.search-results" event when done with a dictionary of the
 * following keys:
 *
 *    - Songs: a list of SearchResult objects, one for each song found
 *    - Artists: a list of SearchResult objects, one for each artist found
 *
 * @param search the query string to send to Pandora
 */
- (BOOL) search: (NSString*) search {
  assert([self authenticated]);
  NSLogd(@"Searching for %@...", search);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:search forKey:@"searchText"];

  PandoraRequest *req = [self defaultRequest:@"music.search"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSDictionary *result = [d objectForKey:@"result"];
    NSLogd(@"%@", result);
    NSMutableDictionary *map = [NSMutableDictionary dictionary];

    NSMutableArray *search_songs, *search_artists;
    search_songs    = [NSMutableArray array];
    search_artists  = [NSMutableArray array];

    [map setObject:search_songs forKey:@"Songs"];
    [map setObject:search_artists forKey:@"Artists"];

    for (NSDictionary *s in [result objectForKey:@"songs"]) {
      SearchResult *r = [[SearchResult alloc] init];
      NSString *name = [NSString stringWithFormat:@"%@ - %@",
                          [s objectForKey:@"songName"],
                          [s objectForKey:@"artistName"]];
      [r setName:name];
      [r setValue:[s objectForKey:@"musicToken"]];
      [search_songs addObject:r];
    }

    for (NSDictionary *a in [result objectForKey:@"artists"]) {
      SearchResult *r = [[SearchResult alloc] init];
      [r setValue:[a objectForKey:@"musicToken"]];
      [r setName:[a objectForKey:@"artistName"]];
      [search_artists addObject:r];
    }

    [self notify:@"hermes.search-results" with:map];
  }];

  return [self sendRequest:req];
}

/**
 * @brief Create a new station
 *
 * A new station can only be created after a search has been made to retrieve
 * some sort of identifier for either an artist or a song. The artist/station
 * provided is the initial seed for the station.
 *
 * Fires the "hermes.station-created" event when done with some userInfo that
 * has one key, "station" which is the station that was created.
 *
 * @param musicId the identifier of the song/artist to create the station for
 */
- (BOOL) createStation: (NSString*)musicId {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:musicId forKey:@"musicToken"];

  PandoraRequest *req = [self defaultRequest:@"station.createStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSDictionary *result = [d objectForKey:@"result"];
    Station *s = [self parseStation:result];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:s forKey:@"station"];
    [stations addObject:s];
    [self notify:@"hermes.station-created" with:dict];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Remove a station from a users's account
 *
 * Fires the "hermes.station-removed" event when done, with no extra information
 *
 * @param stationToken the token of the station to remove
 */
- (BOOL) removeStation: (NSString*)stationToken {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:stationToken forKey:@"stationToken"];

  PandoraRequest *req = [self defaultRequest:@"station.deleteStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    unsigned int i;

    /* Remove the station internally */
    for (i = 0; i < [stations count]; i++) {
      if ([[[stations objectAtIndex:i] token] isEqual:stationToken]) {
        break;
      }
    }

    if ([stations count] == i) {
      NSLogd(@"Deleted unknown station?!");
    } else {
      [stations removeObjectAtIndex:i];
    }

    [self notify:@"hermes.station-removed" with:nil];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Rename a station to have a different name
 *
 * Fires the "hermes.station-renamed" event with no extra information when done.
 *
 * @param stationToken the token of the station retrieved previously which is
 *                     to be renamed
 * @param to the new name of the station
 */
- (BOOL) renameStation: (NSString*)stationToken to:(NSString*)name {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:stationToken forKey:@"stationToken"];
  [d setObject:name forKey:@"stationName"];

  PandoraRequest *req = [self defaultRequest:@"station.renameStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.station-renamed" with:nil];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Fetch extra information about a station
 *
 * Returned information includes data about likes, dislikes, seeds, etc.
 * The "hermes.station-info" event is broadcasted with a user info that has the
 * requested information in the userInfo:
 *
 *    - name, NSString
 *    - created, NSDate
 *    - genres, NSArray of NSString
 *    - art, NSString (url), not present if there's no art
 *    - url, NSString link to the pandora station
 *    - seeds
 *      - artists, NSArray of
 *        - FIGURE THIS OUT
 *        - artistName
 *        - seedId
 *      - songs, NSArray of
 *        - songName
 *        - artistName
 *        - seedId
 *    - likes/dislikes (two keys, same contents)
 *      - feedbackId
 *      - songName
 *      - artistName
 *
 * @param station the station to fetch information for
 */
- (BOOL) stationInfo:(Station *)station {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:[station token]forKey:@"stationToken"];
  [d setObject:[NSNumber numberWithBool:TRUE]
        forKey:@"includeExtendedAttributes"];

  PandoraRequest *req = [self defaultRequest:@"station.getStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    NSDictionary *result = [d objectForKey:@"result"];

    /* General metadata */
    [info setObject:[result objectForKey:@"stationName"] forKey:@"name"];
    uint64_t created = [[[result objectForKey:@"dateCreated"]
                          objectForKey:@"time"] longLongValue];
    [info setObject:[NSDate dateWithTimeIntervalSince1970:created]
             forKey:@"created"];
    NSString *art = [result objectForKey:@"artUrl"];
    if (art != nil) { [info setObject:art forKey:@"art"]; }
    [info setObject:[result objectForKey:@"genre"] forKey:@"genres"];
    [info setObject:[result objectForKey:@"stationDetailUrl"] forKey:@"url"];

    /* Seeds */
    NSMutableDictionary *seeds = [NSMutableDictionary dictionary];
    NSDictionary *music = [result objectForKey:@"music"];
    [seeds setObject:[music objectForKey:@"songs"] forKey:@"songs"];
    [seeds setObject:[music objectForKey:@"artists"] forKey:@"artists"];
    [info setObject:seeds forKey:@"seeds"];

    /* Feedback */
    NSDictionary *feedback = [result objectForKey:@"feedback"];
    [info setObject:[feedback objectForKey:@"thumbsUp"] forKey:@"likes"];
    [info setObject:[feedback objectForKey:@"thumbsDown"] forKey:@"dislikes"];

    [self notify:@"hermes.station-info" with:info];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Delete the feedback for a station
 *
 * The event fired is the "hermes.feedback-deleted" event with no extra
 * information provided.
 *
 * @param feedbackId the name of the feedback to delete
 */
- (BOOL) deleteFeedback: (NSString*)feedbackId {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:feedbackId forKey:@"feedbackId"];

  PandoraRequest *req = [self defaultRequest:@"station.deleteFeedback"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.feedback-deleted" with:nil];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Add a seed to a station
 *
 * The seed must have been previously found via searching Pandora. This fires
 * the "hermes.seed-added" event with the following dictionary keys:
 *
 *    - seedId (NSString, identifier for the seed)
 *    - artistName (NSString, always present)
 *    - songName (NSString, present if the seed was a song)
 *
 * @param token the token of the seed to add
 * @param station the station to add the seed to
 */
- (BOOL) addSeed: (NSString*)token to:(Station*)station {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:token forKey:@"musicToken"];
  [d setObject:[station token] forKey:@"stationToken"];

  PandoraRequest *req = [self defaultRequest:@"station.addMusic"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.seed-added" with:[d objectForKey:@"result"]];
  }];
  return [self sendRequest:req];
}

/**
 * @brief Remove a seed from a station
 *
 * The seed string is found by retrieving the detailed information for a
 * station. The "hermes.seed-removed" event is fired when done with no extra
 * information.
 *
 * @param seedId the identifier of the seed to be removed
 */
- (BOOL) removeSeed: (NSString*)seedId {
  assert([self authenticated]);

  NSMutableDictionary *d = [self defaultDictionary];
  [d setObject:seedId forKey:@"seedId"];

  PandoraRequest *req = [self defaultRequest:@"station.deleteMusic"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.seed-removed" with:nil];
  }];
  return [self sendRequest:req];
}

@end
