#import "Pandora.h"
#import "Crypt.h"
#import "Station.h"
#import "Song.h"
#import "HermesAppDelegate.h"

@implementation SearchResult

@synthesize value, name;

@end

@implementation Pandora

@synthesize authToken, stations;

- (id) init {
  stations = [[NSMutableArray alloc] init];
  retries  = 0;
  return [super init];
}

- (void) dealloc {
  [stations release];
  [authToken release];
  [super dealloc];
}

- (void) notify: (NSString*)msg with:(NSDictionary*)obj {
  [[NSNotificationCenter defaultCenter] postNotificationName:msg object:self
      userInfo:obj];
}

- (void) logout {
  [self notify: @"hermes.logged-out" with:nil];

  [stations removeAllObjects];
  [self setAuthToken:nil];
  [self setListenerID:nil];
}

- (BOOL) authenticated {
  return authToken != nil && listenerID != nil;
}

/**
 * Authenticates with Pandora. Stores information from the response
 */
- (BOOL) authenticate:(NSString*)user :(NSString*)pass :(PandoraRequest*)req {
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

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"authenticateListener"
                                       data:xml
                                   callback:@selector(handleAuthenticate::)
                                       info:req]];
}

- (void) handleAuthenticate: (xmlDocPtr) doc : (PandoraRequest*) req {
  NSString *oldAuthToken = [authToken retain];
  [self setAuthToken: [self xpathText: doc : "//member[name='authToken']/value"]];
  [self setListenerID: [self xpathText: doc : "//member[name='listenerId']/value"]];

  if (req == nil) {
    [self notify:@"hermes.authenticated" with:nil];
  } else {
    NSLogd(@"Retrying request...");
    [req resetResponse];
    [req replaceAuthToken:oldAuthToken with:authToken];
    [self sendRequest:req];
  }
  [oldAuthToken release];
}

- (void) handleStations: (xmlDocPtr) doc {
  int i;
  NSArray *names, *ids;

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
      [station autorelease];
      [stations addObject:station];
    }
  }

  [self notify:@"hermes.stations" with:nil];
}

/**
 * Fetches a list of stations for the logged in user
 */
- (BOOL) fetchStations {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

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

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"getStations"
                                       data:xml
                                   callback:@selector(handleStations:)
                                       info:nil]];
}

- (void) handleFragment: (xmlDocPtr) doc : (NSString*) station_id {
  int i;
  NSString *name = [NSString stringWithFormat:@"hermes.fragment-fetched.%@", station_id];

  NSArray *artists, *titles, *arts, *urls, *station_ids, *music_ids,
    *user_seeds, *ratings, *song_types, *album_urls, *artist_urls, *title_urls,
    *albums;

  artists     = [self xpath: doc : "//member[name='artistSummary']/value"];
  titles      = [self xpath: doc : "//member[name='songTitle']/value"];
  albums      = [self xpath: doc : "//member[name='albumTitle']/value"];
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
    [song autorelease];

    [song setArtist: [artists objectAtIndex: i]];
    [song setTitle: [titles objectAtIndex: i]];
    [song setAlbum: [albums objectAtIndex:i]];
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

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:songs forKey:@"songs"];
  [self notify:name with:dict];
}

/**
 * Gets a fragment of songs from Pandora for the specified station
 */
- (BOOL) getFragment: (NSString*) station_id {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

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

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"getFragment"
                                       data:xml
                                   callback:@selector(handleFragment::)
                                       info:station_id]];
}

- (void) handleSync: (xmlDocPtr) doc {
  [self notify:@"hermes.sync" with:nil];
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

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"sync"
                                       data:xml
                                   callback:@selector(handleSync:)
                                       info:nil]];
}

- (void) handleRating: (xmlDocPtr) doc {
  [self notify:@"hermes.song-rated" with:nil];
}

/**
 * Rate a song, "0" = dislike, "1" = like
 */
- (BOOL) rateSong: (Song*) song : (NSString*) rating {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

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

  [song setRating: rating];
  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"station.addFeedback"
                                       data:xml
                                   callback:@selector(handleRating:)
                                       info:nil]];
}

- (void) handleTired: (xmlDocPtr) doc {
  [self notify:@"hermes.song-tired" with:nil];
}

/**
 * Tell Pandora that we're tired of a specific song
 */
- (BOOL) tiredOfSong: (Song*) song {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

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

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"addTiredSong"
                                       data:xml
                                   callback:@selector(handleTired:)
                                       info:nil]];
}

- (void) handleSearch: (xmlDocPtr) doc {
  NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:3];
  int i;

  NSMutableArray *foundSongs, *foundStations, *foundArtists;
  foundSongs    = [NSMutableArray arrayWithCapacity:10];
  foundStations = [NSMutableArray arrayWithCapacity:10];
  foundArtists  = [NSMutableArray arrayWithCapacity:10];

  [map setObject:foundSongs forKey:@"Songs"];
  [map setObject:foundStations forKey:@"Stations"];
  [map setObject:foundArtists forKey:@"Artists"];

  NSArray *songs = [self xpath:doc :
                    "//member[name='songs']//member[name='musicId' or name='artistSummary'"
                    " or name='songTitle']/value"];
  NSArray *stats = [self xpath:doc :
                    "//member[name='stations']//member[name='musicId'"
                    " or name='stationName']/value"];
  NSArray *artists = [self xpath:doc :
                      "//member[name='artists']//member[name='artistName'"
                      " or name='musicId']/value"];

  SearchResult *r;

  for (i = 0; i < [songs count]; i += 3) {
    r = [[[SearchResult alloc] init] autorelease];

    [r setName:
     [NSString stringWithFormat:@"%@ - %@",
      [songs objectAtIndex:i + 1], [songs objectAtIndex:i + 2]]];

    [r setValue:[songs objectAtIndex:i]];

    [foundSongs addObject:r];
  }

  for (i = 0; i < [stats count]; i += 2) {
    r = [[[SearchResult alloc] init] autorelease];

    [r setName:[stats objectAtIndex:i + 1]];
    [r setValue:[stats objectAtIndex:i]];

    [foundStations addObject:r];
  }

  for (i = 0; i < [artists count]; i += 2) {
    r = [[[SearchResult alloc] init] autorelease];

    [r setName:[artists objectAtIndex:i]];
    [r setValue:[artists objectAtIndex:i + 1]];

    [foundArtists addObject:r];
  }

  [self notify:@"hermes.search-results" with:map];
}

- (BOOL) search: (NSString*) search {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

  NSString *xml = [NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>music.search</methodName>"
      "<params>"
      "<param><value><int>%d</int></value></param>"
      "<param><value><string>%@</string></value></param>"
      "<param><value><string>mi%@</string></value></param>"
      "</params>"
    "</methodCall>",
    [self time], authToken, search
  ];

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"search"
                                       data:xml
                                   callback:@selector(handleSearch:)
                                       info:nil]];
}

- (void) handleCreateStation: (xmlDocPtr) doc {
  [self notify:@"hermes.station-created" with:nil];
}

/**
 * Create a new station, just for kicks
 */
- (BOOL) createStation: (NSString*)musicId {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

  NSString *xml = [NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>station.createStation</methodName>"
      "<params>"
        "<param><value><int>%d</int></value></param>"
        "<param><value><string>%@</string></value></param>"
        "<param><value><string>mi%@</string></value></param>"
        "<param><value><string></string></value></param>"
      "</params>"
    "</methodCall>",
    [self time], authToken, musicId
  ];

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"createStation"
                                       data:xml
                                   callback:@selector(handleCreateStation:)
                                       info:nil]];
}

- (void) handleRemoveStation: (xmlDocPtr)doc : (NSString*)stationId {
  int i;

  for (i = 0; i < [stations count]; i++) {
    if ([[[stations objectAtIndex:i] stationId] isEqual:stationId]) {
      break;
    }
  }

  if ([stations count] == i) {
    NSLogd(@"Deleted unknown station?!");
  } else {
    [stations removeObjectAtIndex:i];
  }

  [self notify:@"hermes.station-removed" with:nil];
}

/**
 * Remove a station from the list, only removing if
 */
- (BOOL) removeStation: (NSString*)stationId {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

  NSString *xml = [NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>station.removeStation</methodName>"
      "<params>"
        "<param><value><int>%d</int></value></param>"
        "<param><value><string>%@</string></value></param>"
        "<param><value><string>%@</string></value></param>"
      "</params>"
    "</methodCall>",
    [self time], authToken, stationId
  ];

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"removeStation"
                                       data:xml
                                   callback:@selector(handleRemoveStation::)
                                       info:stationId]];
}

- (void) handleRenamedStation: (xmlDocPtr)doc {
  [self notify:@"hermes.station-renamed" with:nil];
}

/**
 * Rename a station to have a different name
 */
- (BOOL) renameStation: (NSString*)stationId to:(NSString*)name {
  if (![self authenticated]) {
    @throw [NSException exceptionWithName:@"pandora.need-authentication"
                                   reason:@"Not authenticated yet"
                                 userInfo:nil];
  }

  NSString *xml = [NSString stringWithFormat:
    @"<?xml version=\"1.0\"?>"
    "<methodCall>"
      "<methodName>station.setStationName</methodName>"
      "<params>"
        "<param><value><int>%d</int></value></param>"
        "<param><value><string>%@</string></value></param>"
        "<param><value><string>%@</string></value></param>"
        "<param><value><string>%@</string></value></param>"
      "</params>"
    "</methodCall>",
    [self time], authToken, stationId, name
  ];

  return [self sendRequest:
          [PandoraRequest requestWithMethod:@"setStationName"
                                       data:xml
                                   callback:@selector(handleRenamedStation:)
                                       info:nil]];
}

@end
