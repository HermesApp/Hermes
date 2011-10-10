#import "Pandora.h"
#import "Crypt.h"
#import "Station.h"
#import "Song.h"
#import "HermesAppDelegate.h"

static char *array_xpath = "/methodResponse/params/param/value/array/data/value";

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
  [self setAuthToken: xpathRelative(doc, "//member[name='authToken']/value", NULL)];
  [self setListenerID: xpathRelative(doc, "//member[name='listenerId']/value", NULL)];

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
  char *name_xpath = ".//member[name='stationName']/value";
  char *id_xpath = ".//member[name='stationId']/value";
  char *quickmix_xpath = ".//member[name='isQuickMix']/value/boolean";

  xpathNodes(doc, array_xpath, ^(xmlNodePtr node) {
    NSString *name = xpathRelative(doc, name_xpath, node);
    NSString *stationId = xpathRelative(doc, id_xpath, node);
    if (name == nil || stationId == nil) {
      NSLog(@"Couldn't parse station, skipping. Name: %@, ID: %@",
            name, stationId);
      return;
    }

    Station *station = [[Station alloc] init];

    [station setName:name];
    [station setStationId:stationId];
    [station setRadio:self];

    if ([xpathRelative(doc, quickmix_xpath, node) isEqualToString:@"1"]) {
      [station setName:@"QuickMix"];
    }

    if ([stations containsObject:station]) {
      [station release];
    } else {
      [station autorelease];
      [stations addObject:station];
    }
  });

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
  NSMutableArray *songs = [NSMutableArray array];

  xpathNodes(doc, array_xpath, ^(xmlNodePtr node) {
    Song *song = [[Song alloc] init];
    [song autorelease];

    [song setArtist: xpathRelative(doc, ".//member[name='artistSummary']/value", node)];
    [song setTitle: xpathRelative(doc, ".//member[name='songTitle']/value", node)];
    [song setAlbum: xpathRelative(doc, ".//member[name='albumTitle']/value", node)];
    [song setArt: xpathRelative(doc, ".//member[name='artRadio']/value", node)];
    NSString *url = xpathRelative(doc, ".//member[name='audioURL']/value", node);
    [song setUrl: [Song decryptURL:url]];
    [song setStationId: xpathRelative(doc, ".//member[name='stationId']/value", node)];
    [song setMusicId: xpathRelative(doc, ".//member[name='musicId']/value", node)];
    [song setUserSeed: xpathRelative(doc, ".//member[name='userSeed']/value", node)];
    [song setRating: xpathRelative(doc, ".//member[name='rating']/value/int", node)];
    [song setSongType: xpathRelative(doc, ".//member[name='songType']/value/int", node)];
    [song setAlbumUrl: xpathRelative(doc, ".//member[name='albumDetailURL']/value", node)];
    [song setArtistUrl:  xpathRelative(doc, ".//member[name='artistDetailURL']/value", node)];
    [song setTitleUrl: xpathRelative(doc, ".//member[name='songDetailURL']/value", node)];

    [songs addObject: song];
  });

  NSString *name = [NSString stringWithFormat:@"hermes.fragment-fetched.%@", station_id];
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

  if ([rating isEqual:@"1"]) {
    [song setRating: rating];
  } else {
    [song setRating: @"-1"];
  }
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

  NSMutableArray *search_songs, *search_stations, *search_artists;
  search_songs    = [NSMutableArray array];
  search_stations = [NSMutableArray array];
  search_artists  = [NSMutableArray array];

  [map setObject:search_songs forKey:@"Songs"];
  [map setObject:search_stations forKey:@"Stations"];
  [map setObject:search_artists forKey:@"Artists"];

  xpathNodes(doc, "//member[name='songs']/value/array/data/value", ^(xmlNodePtr node) {
    SearchResult *r = [[[SearchResult alloc] init] autorelease];
    NSString *artist = xpathRelative(doc, ".//member[name='artistSummary']/value", node);
    NSString *song = xpathRelative(doc, ".//member[name='songTitle']/value", node);

    [r setName:[NSString stringWithFormat:@"%@ - %@", artist, song]];
    [r setValue:xpathRelative(doc, ".//member[name='musicId']/value", node)];
    [search_songs addObject:r];
  });

  xpathNodes(doc, "//member[name='stations']/value/array/data/value", ^(xmlNodePtr node) {
    SearchResult *r = [[[SearchResult alloc] init] autorelease];
    [r setValue:xpathRelative(doc, ".//member[name='musicId']/value", node)];
    [r setName:xpathRelative(doc, ".//member[name='stationName']/value", node)];
    [search_stations addObject:r];
  });

  xpathNodes(doc, "//member[name='artists']/value/array/data/value", ^(xmlNodePtr node) {
    SearchResult *r = [[[SearchResult alloc] init] autorelease];
    [r setValue:xpathRelative(doc, ".//member[name='musicId']/value", node)];
    [r setName:xpathRelative(doc, ".//member[name='artistName']/value", node)];
    [search_artists addObject:r];
  });

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
