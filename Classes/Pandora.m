#import "HermesAppDelegate.h"
#import "Pandora.h"
#import "Pandora/Crypt.h"
#import "Pandora/Song.h"
#import "Pandora/Station.h"

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
  [stations removeAllObjects];
  [self notify: @"hermes.logged-out" with:nil];
}

- (void) logoutNoNotify {
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
  d[@"userAuthToken"] = user_auth_token;
  d[@"syncTime"]      = [self syncTimeNum];
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

  [station setName:           s[@"stationName"]];
  [station setStationId:      s[@"stationId"]];
  [station setToken:          s[@"stationToken"]];
  [station setShared:        [s[@"isShared"] boolValue]];
  [station setAllowAddMusic: [s[@"allowAddMusic"] boolValue]];
  [station setAllowRename:   [s[@"allowRename"] boolValue]];
  [station setRadio:self];

  if ([s[@"isQuickMix"] boolValue]) {
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
- (BOOL) authenticate:(NSString*)user
             password:(NSString*)pass
              request:(PandoraRequest*)req {
  if (partner_id == nil) {
    return [self partnerLogin: ^() {
      [self authenticate:user password:pass request:req];
    }];
  }

  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  d[@"loginType"]        = @"user";
  d[@"username"]         = user;
  d[@"password"]         = pass;
  d[@"partnerAuthToken"] = partner_auth_token;
  d[@"syncTime"]         = [self syncTimeNum];

  PandoraRequest *r = [[PandoraRequest alloc] init];
  [r setRequest: d];
  [r setMethod: @"auth.userLogin"];
  [r setPartnerId: partner_id];
  [r setAuthToken: partner_auth_token];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    user_auth_token = result[@"userAuthToken"];
    user_id = result[@"userId"];

    if (req == nil) {
      [self notify:@"hermes.authenticated" with:nil];
    } else {
      NSLogd(@"Retrying request...");
      PandoraRequest *newreq = [self defaultRequest:[req method]];
      [newreq setRequest:[req request]];
      [newreq request][@"userAuthToken"] = user_auth_token;
      [newreq setCallback:[req callback]];
      [newreq setTls:[req tls]];
      [newreq setEncrypted:[req encrypted]];
      [self sendRequest:newreq];
    }
  }];
  return [self sendRequest:r];
}

- (BOOL) sendAuthenticatedRequest: (PandoraRequest*) req {
  if ([self authenticated]) {
    return [self sendRequest:req];
  }
  NSString *user = [[NSApp delegate] getCachedUsername];
  NSString *pass = [[NSApp delegate] getCachedPassword];
  return [self authenticate:user password:pass request:req];
}

/**
 * @brief Fetches a list of stations for the logged in user
 *
 * Fires the "hermes.stations" event with no extra information. All of the
 * stations found are stored internally in this Pandora object.
 */
- (BOOL) fetchStations {
  NSLogd(@"Fetching stations...");

  NSMutableDictionary *d = [self defaultDictionary];

  PandoraRequest *r = [self defaultRequest:@"user.getStationList"];
  [r setRequest:d];
  [r setTls:FALSE];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    for (NSDictionary *s in result[@"stations"]) {
      Station *station = [self parseStation:s];
      if (![stations containsObject:station]) {
        [stations addObject:station];
      }
    };

    [self notify:@"hermes.stations" with:nil];
  }];

  return [self sendAuthenticatedRequest:r];
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
  NSLogd(@"Getting fragment for %@...", [station name]);

  NSMutableDictionary *d = [self defaultDictionary];
  d[@"stationToken"] = [station token];
  d[@"additionalAudioUrl"] = @"HTTP_32_AACPLUS_ADTS,HTTP_64_AACPLUS_ADTS,HTTP_128_MP3";

  PandoraRequest *r = [self defaultRequest:@"station.getPlaylist"];
  [r setRequest:d];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    NSMutableArray *songs = [NSMutableArray array];

    for (NSDictionary *s in result[@"items"]) {
      if (s[@"adToken"] != nil) continue; // Skip if this is an adToken

      Song *song = [[Song alloc] init];

      [song setArtist: s[@"artistName"]];
      [song setTitle: s[@"songName"]];
      [song setAlbum: s[@"albumName"]];
      [song setArt: s[@"albumArtUrl"]];
      [song setStationId: s[@"stationId"]];
      [song setToken: s[@"trackToken"]];
      [song setNrating: s[@"songRating"]];
      [song setAlbumUrl: s[@"albumDetailUrl"]];
      [song setArtistUrl: s[@"artistDetailUrl"]];
      [song setTitleUrl: s[@"songDetailUrl"]];
      [song setStation:station];

      id _urls = s[@"additionalAudioUrl"];
      if ([_urls isKindOfClass:[NSArray class]]) {
        NSArray *urls = _urls;
        [song setLowUrl:urls[0]];
        if ([urls count] > 1) {
          [song setMedUrl:urls[1]];
        } else {
          [song setMedUrl:[song lowUrl]];
          NSLog(@"bad medium format specified in request");
        }
        if ([urls count] > 2) {
          [song setHighUrl:urls[2]];
        } else {
          [song setHighUrl:[song medUrl]];
          NSLog(@"bad high format specified in request");
        }
      } else {
        NSLog(@"all bad formats in request?");
        [song setLowUrl:_urls];
        [song setMedUrl:_urls];
        [song setHighUrl:_urls];
      }

      [songs addObject: song];
    };

    NSString *name = [NSString stringWithFormat:@"hermes.fragment-fetched.%@",
                        [station token]];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"songs"] = songs;
    [self notify:name with:d];
  }];

  return [self sendAuthenticatedRequest:r];
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
  d[@"username"] = PARTNER_USERNAME;
  d[@"password"] = PARTNER_PASSWORD;
  d[@"deviceModel"] = PARTNER_DEVICEID;
  d[@"version"] = PANDORA_API_VERSION;
  d[@"includeUrls"] = [NSNumber numberWithBool:TRUE];

  PandoraRequest *req = [[PandoraRequest alloc] init];
  [req setRequest: d];
  [req setMethod: @"auth.partnerLogin"];
  [req setEncrypted:FALSE];
  [req setCallback:^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    partner_auth_token = result[@"partnerAuthToken"];
    partner_id = result[@"partnerId"];
    NSData *sync = PandoraDecrypt(result[@"syncTime"]);
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
  NSLogd(@"Rating song '%@' as %d...", [song title], liked);

  if (liked == TRUE) {
    [song setNrating:@1];
  } else {
    [song setNrating:@-1];
  }

  NSMutableDictionary *d = [self defaultDictionary];
  d[@"trackToken"] = [song token];
  d[@"isPositive"] = @(liked);
  d[@"stationToken"] = [[song station] token];

  PandoraRequest *req = [self defaultRequest:@"station.addFeedback"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* _) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"song"] = song;
    [self notify:@"hermes.song-rated" with:dict];
  }];
  return [self sendAuthenticatedRequest:req];
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
  NSLogd(@"Getting tired of %@...", [song title]);

  NSMutableDictionary *d = [self defaultDictionary];
  d[@"trackToken"] = [song token];

  PandoraRequest *req = [self defaultRequest:@"user.sleepSong"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* _) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"song"] = song;
    [self notify:@"hermes.song-tired" with:dict];
  }];

  return [self sendAuthenticatedRequest:req];
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
  NSLogd(@"Searching for %@...", search);

  NSMutableDictionary *d = [self defaultDictionary];
  d[@"searchText"] = search;

  PandoraRequest *req = [self defaultRequest:@"music.search"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSDictionary *result = d[@"result"];
    NSLogd(@"%@", result);
    NSMutableDictionary *map = [NSMutableDictionary dictionary];

    NSMutableArray *search_songs, *search_artists;
    search_songs    = [NSMutableArray array];
    search_artists  = [NSMutableArray array];

    map[@"Songs"] = search_songs;
    map[@"Artists"] = search_artists;

    for (NSDictionary *s in result[@"songs"]) {
      SearchResult *r = [[SearchResult alloc] init];
      NSString *name = [NSString stringWithFormat:@"%@ - %@",
                          s[@"songName"],
                          s[@"artistName"]];
      [r setName:name];
      [r setValue:s[@"musicToken"]];
      [search_songs addObject:r];
    }

    for (NSDictionary *a in result[@"artists"]) {
      SearchResult *r = [[SearchResult alloc] init];
      [r setValue:a[@"musicToken"]];
      [r setName:a[@"artistName"]];
      [search_artists addObject:r];
    }

    [self notify:@"hermes.search-results" with:map];
  }];

  return [self sendAuthenticatedRequest:req];
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
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"musicToken"] = musicId;

  PandoraRequest *req = [self defaultRequest:@"station.createStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSDictionary *result = d[@"result"];
    Station *s = [self parseStation:result];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"station"] = s;
    [stations addObject:s];
    [self notify:@"hermes.station-created" with:dict];
  }];
  return [self sendAuthenticatedRequest:req];
}

/**
 * @brief Remove a station from a users's account
 *
 * Fires the "hermes.station-removed" event when done, with no extra information
 *
 * @param stationToken the token of the station to remove
 */
- (BOOL) removeStation: (NSString*)stationToken {
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"stationToken"] = stationToken;

  PandoraRequest *req = [self defaultRequest:@"station.deleteStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    unsigned int i;

    /* Remove the station internally */
    for (i = 0; i < [stations count]; i++) {
      if ([[stations[i] token] isEqual:stationToken]) {
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
  return [self sendAuthenticatedRequest:req];
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
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"stationToken"] = stationToken;
  d[@"stationName"] = name;

  PandoraRequest *req = [self defaultRequest:@"station.renameStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.station-renamed" with:nil];
  }];
  return [self sendAuthenticatedRequest:req];
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
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"stationToken"] = [station token];
  d[@"includeExtendedAttributes"] = [NSNumber numberWithBool:TRUE];

  PandoraRequest *req = [self defaultRequest:@"station.getStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    NSDictionary *result = d[@"result"];

    /* General metadata */
    info[@"name"] = result[@"stationName"];
    uint64_t created = [result[@"dateCreated"][@"time"] longLongValue];
    info[@"created"] = [NSDate dateWithTimeIntervalSince1970:created];
    NSString *art = result[@"artUrl"];
    if (art != nil) { info[@"art"] = art; }
    info[@"genres"] = result[@"genre"];
    info[@"url"] = result[@"stationDetailUrl"];

    /* Seeds */
    NSMutableDictionary *seeds = [NSMutableDictionary dictionary];
    NSDictionary *music = result[@"music"];
    seeds[@"songs"] = music[@"songs"];
    seeds[@"artists"] = music[@"artists"];
    info[@"seeds"] = seeds;

    /* Feedback */
    NSDictionary *feedback = result[@"feedback"];
    info[@"likes"] = feedback[@"thumbsUp"];
    info[@"dislikes"] = feedback[@"thumbsDown"];

    [self notify:@"hermes.station-info" with:info];
  }];
  return [self sendAuthenticatedRequest:req];
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
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"feedbackId"] = feedbackId;

  PandoraRequest *req = [self defaultRequest:@"station.deleteFeedback"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.feedback-deleted" with:nil];
  }];
  return [self sendAuthenticatedRequest:req];
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
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"musicToken"] = token;
  d[@"stationToken"] = [station token];

  PandoraRequest *req = [self defaultRequest:@"station.addMusic"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.seed-added" with:d[@"result"]];
  }];
  return [self sendAuthenticatedRequest:req];
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
  NSMutableDictionary *d = [self defaultDictionary];
  d[@"seedId"] = seedId;

  PandoraRequest *req = [self defaultRequest:@"station.deleteMusic"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.seed-removed" with:nil];
  }];
  return [self sendAuthenticatedRequest:req];
}

/**
 * @brief Fetch the "genre stations" from pandora
 *
 * Pandora provides some pre-defined genre stations available to create a
 * station from, and this provides the API to fetch those. The
 * "hermes.genre-stations" event is fired when done with the extra information
 * of the response from Pandora.
 */
- (BOOL) genreStations {
  NSMutableDictionary *d = [self defaultDictionary];

  PandoraRequest *req = [self defaultRequest:@"station.getGenreStations"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self notify:@"hermes.genre-stations" with:d[@"result"]];
  }];
  return [self sendAuthenticatedRequest:req];
}

@end
