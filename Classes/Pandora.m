#import "Pandora.h"
#import "Crypt.h"
#import "Station.h"
#import "Song.h"

@implementation Pandora

@synthesize authToken, stations;

- (id) init {
  stations = [[NSMutableArray alloc] init];
  return [super init];
}

- (void) dealloc {
  [stations release];
  [super dealloc];
}

- (void) notify: (NSString*)msg with:(NSDictionary*)obj {
  [[NSNotificationCenter defaultCenter] postNotificationName:msg object:self
      userInfo:obj];
}

- (void) logout {
  Station *station;

  [self notify: @"hermes.logged-out" with:nil];

  while ([stations count] > 0) {
    station = [stations objectAtIndex:0];
    [stations removeObjectAtIndex:0];
    [station release];
  }

  [authToken release];
  [listenerID release];

  authToken = nil;
  listenerID = nil;
}

- (BOOL) authenticated {
  return authToken != nil && listenerID != nil;
}

/**
 * Authenticates with Pandora. Stores information from the response
 */
- (BOOL) authenticate:(NSString*)user :(NSString*)pass {
  NSString *xml = [NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>listener.authenticateListener</methodName>"
      "<params>"
        "<param><value><int>%d</int></value></param>"
        "<param><value><string>%@</string></value></param>"
        "<param><value><string>%@</string></value></param>"
      "</params>"
    "</methodCall>",
      [self time], user, pass
    ];

  return [self sendRequest: @"authenticateListener" : [Crypt encrypt: xml] :
    @selector(handleAuthenticate:)];
}

- (void) handleAuthenticate: (xmlDocPtr) doc {
  authToken = nil;
  listenerID = nil;

  if (doc != NULL) {
    authToken  = [self xpathText: doc : "//member[name='authToken']/value"];
    listenerID = [self xpathText: doc : "//member[name='listenerId']/value"];
  }

  [self notify:@"hermes.authenticated" with:nil];
}

/**
 * Fetches a list of stations for the logged in user
 */
- (BOOL) fetchStations {
  NSString *xml = [NSString stringWithFormat:
     @"<?xml version=\"1.0\"?>"
     "<methodCall>"
       "<methodName>station.getStations</methodName>"
       "<params>"
         "<param><value><int>%d</int></value></param>"
         "<param><value><string>%@</string></value></param>"
       "</params>"
     "</methodCall>",
     [self time], authToken
   ];

  return [self sendRequest: @"getStations" : [Crypt encrypt: xml] :
      @selector(handleStations:)];
}

- (void) handleStations: (xmlDocPtr) doc {
  int i;
  NSArray *names, *ids;

  if (doc == NULL) {
    [self notify:@"hermes.stations" with:nil];
    return;
  }

  names = [self xpath: doc : "//member[name='stationName']/value"];
  ids   = [self xpath: doc : "//member[name='stationId']/value"];

  for (i = 0; i < [names count]; i++) {
    Station *station = [[Station alloc] init];

    [station setName:[names objectAtIndex: i]];
    [station setStationId:[ids objectAtIndex: i]];
    [station setRadio:self];

    if ([[station name] rangeOfString: @"QuickMix"].length != 0) {
      [station setName:@"QuickMix"];
    }

    if ([stations containsObject:station]) {
      [station release];
    } else {
      [stations addObject:station];
    }
  }

  [self notify:@"hermes.stations" with:nil];
}

/**
 * Gets a fragment of songs from Pandora for the specified station
 */
- (BOOL) getFragment: (NSString*) station_id {
  NSString *xml = [NSString stringWithFormat:
     @"<?xml version=\"1.0\"?>"
     "<methodCall>"
       "<methodName>playlist.getFragment</methodName>"
       "<params>"
         "<param><value><int>%d</int></value></param>"
         "<param><value><string>%@</string></value></param>"
         "<param><value><string>%@</string></value></param>"
         "<param><value><string>0</string></value></param>"
         "<param><value><string></string></value></param>"
         "<param><value><string></string></value></param>"
         "<param><value><string>mp3</string></value></param>"
         "<param><value><string>0</string></value></param>"
         "<param><value><string>0</string></value></param>"
       "</params>"
     "</methodCall>",
     [self time], authToken, station_id
   ];

  return [self sendRequest: @"getStations" : [Crypt encrypt: xml] :
          @selector(handleFragment::) : station_id];
}

- (void) handleFragment: (xmlDocPtr) doc : (NSString*) station_id {
  int i;
  NSString *name = [NSString stringWithFormat:@"hermes.fragment-fetched.%@", station_id];

  NSArray *artists, *titles, *arts, *urls, *station_ids, *music_ids,
    *user_seeds, *ratings, *song_types, *album_urls, *artist_urls, *title_urls;
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];

  if (doc == NULL) {
    [self notify:name with:dict];
    return;
  }

  artists     = [self xpath: doc : "//member[name='artistSummary']/value"];
  titles      = [self xpath: doc : "//member[name='songTitle']/value"];
  arts        = [self xpath: doc : "//member[name='artRadio']/value"];
  urls        = [self xpath: doc : "//member[name='audioURL']/value"];
  station_ids = [self xpath: doc : "//member[name='stationId']/value"];
  music_ids   = [self xpath: doc : "//member[name='musicId']/value"];
  user_seeds  = [self xpath: doc : "//member[name='userSeed']/value"];
  ratings     = [self xpath: doc : "//member[name='rating']/value/int"];
  song_types  = [self xpath: doc : "//member[name='songType']/value/int"];
  album_urls  = [self xpath: doc : "//member[name='albumDetailURL']/value"];
  artist_urls = [self xpath: doc : "//member[name='artistDetailURL']/value"];
  title_urls  = [self xpath: doc : "//member[name='songDetailURL']/value"];

  NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[artists count]];

  for (i = 0; i < [artists count]; i++) {
    Song *song = [[Song alloc] init];

    [song setArtist: [artists objectAtIndex: i]];
    [song setTitle: [titles objectAtIndex: i]];
    [song setArt: [arts objectAtIndex: i]];
    [song setUrl: [Song decryptURL: [urls objectAtIndex: i]]];
    [song setStationId: [station_ids objectAtIndex: i]];
    [song setMusicId: [music_ids objectAtIndex: i]];
    [song setUserSeed: [user_seeds objectAtIndex: i]];
    [song setRating: [ratings objectAtIndex: i]];
    [song setSongType: [song_types objectAtIndex: i]];
    [song setAlbumUrl: [album_urls objectAtIndex: i]];
    [song setArtistUrl:  [artist_urls objectAtIndex: i]];
    [song setTitleUrl: [title_urls objectAtIndex: i]];

    [songs addObject: song];
  }

  [dict setObject:songs forKey:@"songs"];

  [self notify:name with:dict];
}

/**
 * Sync with Pandora
 */
- (BOOL) sync {
  NSString *xml =
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>misc.sync</methodName>"
      "<params></params>"
    "</methodCall>";

  return [self sendRequest: @"sync" : [Crypt encrypt: xml] : @selector(handleSync:)];
}

- (void) handleSync: (xmlDocPtr) doc {
  [self notify:@"hermes.sync" with:nil];
}

/**
 * Rate a song, "0" = dislike, "1" = like
 */
- (BOOL) rateSong: (Song*) song : (NSString*) rating {
  NSString *xml = [NSString stringWithFormat:
     @"<?xml version=\"1.0\"?>"
     "<methodCall>"
       "<methodName>station.addFeedback</methodName>"
       "<params>"
         "<param><value><int>%d</int></value></param>"
         "<param><value><string>%@</string></value></param>"
         "<param><value><string>%@</string></value></param>"
         "<param><value><string>%@</string></value></param>"
         "<param><value><string>%@</string></value></param>"
         "<param><value>%@</value></param>"
         "<param><value><boolean>%@</boolean></value></param>"
         "<param><value><boolean>0</boolean></value></param>"
         "<param><value><int>%@</int></value></param>"
       "</params>"
     "</methodCall>",
     [self time], authToken, [song stationId], [song musicId],
       [song userSeed], @"undefined", rating, [song songType]
   ];

  song.rating = rating;
  return [self sendRequest: @"station.addFeedback" : [Crypt encrypt: xml] :
      @selector(handleRating:)];
}

- (void) handleRating: (xmlDocPtr) doc {
  [self notify:@"hermes.song-rated" with:nil];
}

/**
 * Tell Pandora that we're tired of a specific song
 */
- (BOOL) tiredOfSong: (Song*) song {
  NSString *xml = [NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>listener.addTiredSong</methodName>"
      "<params>"
      "<param><value><int>%d</int></value></param>"
      "<param><value><string>%@</string></value></param>"
      "<param><value><string>%@</string></value></param>"
      "<param><value><string>%@</string></value></param>"
      "<param><value><string>%@</string></value></param>"
      "</params>"
    "</methodCall>",
    [self time], authToken, [song musicId], [song userSeed], [song stationId]
  ];

  return [self sendRequest: @"addTiredSong" : [Crypt encrypt: xml] :
      @selector(handleTired:)];
}

- (void) handleTired: (xmlDocPtr) doc {
  [self notify:@"hermes.song-tired" with:nil];
}

@end
