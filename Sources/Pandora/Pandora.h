@class Station;

#import "Pandora/Song.h"


#define PANDORA_API_PATH @"/services/json/"
#define PANDORA_API_VERSION @"5"

#define INVALID_SYNC_TIME     13
#define INVALID_AUTH_TOKEN    1001
#define INVALID_PARTNER_LOGIN 1002
#define INVALID_USERNAME      1011
#define INVALID_PASSWORD      1012
#define NO_SEEDS_LEFT         1032

typedef void(^SyncCallback)(void);
typedef void(^PandoraCallback)(NSDictionary*);

#pragma mark - PandoraSearchResult

/**
 * Wrapper for search result from "music.search" method
 */
@interface PandoraSearchResult : NSObject

@property (retain) NSString *name;
@property (retain) NSString *value;


@end

#pragma mark - PandoraRequest

/**
 * Pandora request
 */
@interface PandoraRequest : NSObject <NSCopying>

#pragma mark URL parameters
/**
 * Pandora API method to use
 *
 * Complete list here: http://6xq.net/playground/pandora-apidoc/json/methods/
 */
@property (retain) NSString *method;

/**
 * Auth token obtained from auth.userLogin (or auth.partnerLogin)
 */
@property (retain) NSString *authToken;

/**
 * Partner id as obtained by auth.partnerLogin
 */
@property (retain) NSString *partnerId;

/**
 * User id obtained from auth.userLogin
 */
@property (retain) NSString *userId;

#pragma mark JSON data
@property (retain) NSDictionary *request;
@property (retain) NSMutableData *response;

#pragma mark Internal metadata
@property (copy) PandoraCallback callback;
@property (assign) BOOL tls;
@property (assign) BOOL encrypted;

@end

#pragma mark - Pandora

/* Implementation of Pandora's API */
@interface Pandora : NSObject {
  NSMutableArray *stations;
  int retries;

  NSString *partner_id;
  NSString *partner_auth_token;
  NSString *user_auth_token;
  NSString *user_id;
  uint64_t sync_time;
  uint64_t start_time;
  int64_t syncOffset;
}

@property (readonly) NSArray* stations;
@property (strong) NSDictionary *device;
@property (retain) NSNumber *cachedSubscriberStatus;

#pragma mark - Error handling

+ (NSString*) stringForErrorCode: (int) code;

#pragma mark - Crypto

- (NSData *)encryptData:(NSData *)data;
- (NSData *)decryptString:(NSString *)string;

#pragma mark - Authentication

/**
 * @brief Authenticates with Pandora
 *
 * When completed, fires the "hermes.authenticated" event so long as the
 * provided request to retry is nil. This method calls the
 * "auth.partnerLogin", "auth.userLogin", and "user.canSubscribe" API
 * methods indirectly.
 *
 * @param user the username to log in with
 * @param pass the password to log in with
 * @param req an optional request which will be retried once the authentication
 *        has completed
 */
- (BOOL) authenticate:(NSString*)user
             password:(NSString*)password
              request:(PandoraRequest*)req;

/**
 * @brief Log in the "partner" with Pandora
 *
 * Retrieves the sync time and the partner auth token.
 *
 * @param callback a callback to be invoked once the synchronization and login
 *        is done
 */
- (BOOL) doPartnerLogin: (SyncCallback) cb;

- (void) logout;
- (void) logoutNoNotify;
- (BOOL) isAuthenticated;

#pragma mark - Station Manipulation

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
- (BOOL) createStation: (NSString*) musicId;

/**
 * @brief Remove a station from a users's account
 *
 * Fires the "hermes.station-removed" event when done, with no extra information
 *
 * @param stationToken the token of the station to remove
 */
- (BOOL) removeStation: (NSString*) stationToken;

/**
 * @brief Rename a station to have a different name
 *
 * Fires the "hermes.station-renamed" event with no extra information when done.
 *
 * @param stationToken the token of the station retrieved previously which is
 *                     to be renamed
 * @param to the new name of the station
 */
- (BOOL) renameStation: (NSString*)stationToken to:(NSString*)name;

#pragma mark Fetch & parse station information from API

/**
 * @brief Fetches a list of stations for the logged in user
 *
 * Fires the "hermes.stations" event with no extra information. All of the
 * stations found are stored internally in this Pandora object.
 */
- (BOOL) fetchStations;

/**
 * @brief Get a small list of songs for a station
 *
 * Fires the "hermes.fragment-fetched.XX" where XX is replaced by the station
 * token. The userInfo for the notification has one key, "songs", which contains
 * an array of Song objects describing the next songs for the station
 *
 * @param station the station to fetch more songs for
 */
- (BOOL) fetchPlaylistForStation: (Station*)station;

/**
 * @brief Fetch the "genre stations" from pandora
 *
 * Pandora provides some pre-defined genre stations available to create a
 * station from, and this provides the API to fetch those. The
 * "hermes.genre-stations" event is fired when done with the extra information
 * of the response from Pandora.
 */
- (BOOL) fetchGenreStations;

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
- (BOOL) fetchStationInfo: (Station*) station;

#pragma mark Seed & Feedback Management (see also Song Manipulation)

/**
 * @brief Delete the feedback for a station
 *
 * The event fired is the "hermes.feedback-deleted" event with no extra
 * information provided.
 *
 * @param feedbackId the name of the feedback to delete
 */
- (BOOL) deleteFeedback: (NSString*)feedbackId;

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
- (BOOL) addSeed: (NSString*)token toStation:(Station*)station;

/**
 * @brief Remove a seed from a station
 *
 * The seed string is found by retrieving the detailed information for a
 * station. The "hermes.seed-removed" event is fired when done with no extra
 * information.
 *
 * @param seedId the identifier of the seed to be removed
 */
- (BOOL) removeSeed: (NSString*)seedId;

#pragma mark Sort stations in UI

- (void) sortStations:(NSInteger)sort;

#pragma mark - Song Manipulation

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
- (BOOL) rateSong:(Song*) song as:(BOOL) liked;

/**
 * @brief Delete a rating for a song
 *
 * Fires the same event for deleteFeedback
 *
 * @param song the song to delete a user's rating for
 */
- (BOOL) deleteRating:(Song*)song;

/**
 * @brief Inform Pandora that the specified song shouldn't be played for awhile
 *
 * Fires the "hermes.song-tired" event with a dictionary with the key "song"
 * when the event is done. The song of the event is the same one as provided
 * here.
 *
 * @param song the song to tell Pandora not to play for awhile
 */
- (BOOL) tiredOfSong: (Song*)song;

#pragma mark - Search for music

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
- (BOOL) search: (NSString*) search;

#pragma mark - Prepare and Send Requests

/**
 * @brief Send a request to Pandora
 *
 * All requests are performed asynchronously, so the callback listed in the
 * specified request will be invoked when the request completes.
 *
 * @param request the request to send. All information must be filled out
 *        beforehand which is related to this request
 * @return YES if the request went through, or NO otherwise.
 */
- (BOOL) sendRequest: (PandoraRequest*) request;

@end

