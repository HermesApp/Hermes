#include <libxml/parser.h>
#include <libxml/xpath.h>
#include <string.h>

#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLResponse.h>

#import "Pandora.h"
#import "Crypt.h"
#import "Station.h"
#import "Song.h"

@implementation Pandora

@synthesize authToken, listenerID, stations;

- (id) init {
  stations = [[NSMutableArray alloc] init];
  return self;
}

- (void) dealloc {
  [stations release];
  [super dealloc];
}

/**
 * Gets the current UNIX time
 */
- (int) time {
  return [[NSDate date] timeIntervalSince1970];
}

/**
 * Performs and XPATH query on the specified document, returning the array of
 * contents for each node matched
 */
- (NSArray*) xpath: (xmlDocPtr) doc : (char*) xpath {
  xmlXPathContextPtr xpathCtx;
  xmlXPathObjectPtr xpathObj;

  /* Create xpath evaluation context */
  xpathCtx = xmlXPathNewContext(doc);
  if(xpathCtx == NULL) {
    return nil;
  }

  /* Evaluate xpath expression */
  xpathObj = xmlXPathEvalExpression((xmlChar *)xpath, xpathCtx);
  if(xpathObj == NULL) {
    xmlXPathFreeContext(xpathCtx);
    return nil;
  }

  xmlNodeSetPtr nodes = xpathObj->nodesetval;
  if (!nodes) {
    xmlXPathFreeContext(xpathCtx);
    xmlXPathFreeObject(xpathObj);
    return nil;
  }

  NSMutableArray *resultNodes = [NSMutableArray array];
  char *content;
  for (NSInteger i = 0; i < nodes->nodeNr; i++) {
    if (nodes->nodeTab[i]->children == NULL || nodes->nodeTab[i]->children->content == NULL) {
      content = "";
    } else {
      content = (char*) nodes->nodeTab[i]->children->content;
    }

    NSString *str = [NSString stringWithCString: content encoding:NSUTF8StringEncoding];

    [resultNodes addObject: str];
  }

  /* Cleanup */
  xmlXPathFreeObject(xpathObj);
  xmlXPathFreeContext(xpathCtx);

  return resultNodes;
}

/**
 * Performs and xpath query and returns the content of the first node
 */
- (NSString*) xpathText: (xmlDocPtr)doc : (char*) xpath {
  NSArray  *arr = [self xpath: doc : xpath];
  NSString *ret = nil;

  if (arr != nil && [arr objectAtIndex: 0] != nil) {
    ret = [arr objectAtIndex: 0];
    [ret retain];
  }

//  [arr release];
  return ret;
}

/**
 * Authenticates with Pandora. Stores information from the response
 */
- (BOOL) authenticate:(NSString*)user :(NSString*)pass {
  xmlDocPtr doc;
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

  xml = [Crypt encrypt: xml];
  doc = [self sendRequest: @"authenticateListener" : xml];

  authToken = nil;
  listenerID = nil;

  if (doc != NULL) {
    authToken  = [self xpathText: doc : "//member[name='authToken']/value"];
    listenerID = [self xpathText: doc : "//member[name='listenerId']/value"];

    xmlFreeDoc(doc);
  }

  return authToken != nil;
}

/**
 * Fetches a list of stations for the logged in user
 */
- (BOOL) fetchStations {
  int i;
  NSArray *names, *ids;
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

  xml = [Crypt encrypt: xml];
  xmlDocPtr doc = [self sendRequest: @"getStations" : xml];
  if (doc == NULL) {
    return NO;
  }

  names = [self xpath: doc : "//member[name='stationName']/value"];
  ids   = [self xpath: doc : "//member[name='stationId']/value"];

  while ([stations count] > 0) {
    [[stations objectAtIndex: 0] release];
    [stations removeObjectAtIndex: 0];
  }

  for (i = 0; i < [names count]; i++) {
    Station *station = [[Station alloc] init];

    station.name       = [names objectAtIndex: i];
    station.station_id = [ids objectAtIndex: i];
    station.radio      = self;

    if ([[station name] rangeOfString: @"QuickMix"].length != 0) {
      station.name = @"QuickMix";
    }

    [stations addObject: station];
  }

  xmlFreeDoc(doc);
  return YES;
}

/**
 * Gets a fragment of songs from Pandora for the specified station
 */
- (NSArray*) getFragment: (NSString*) station_id {
  int i;

  NSArray *artists, *titles, *arts, *urls, *station_ids, *music_ids,
    *user_seeds, *ratings, *song_types, *album_urls, *artist_urls, *title_urls;

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

  xml = [Crypt encrypt: xml];
  xmlDocPtr doc = [self sendRequest: @"getStations" : xml];
  if (doc == NULL) {
      return nil;
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

  NSMutableArray *songs = [[NSMutableArray alloc] init];

  for (i = 0; i < [artists count]; i++) {
    Song *song = [[Song alloc] init];

    song.artist     = [artists objectAtIndex: i];
    song.title      = [titles objectAtIndex: i];
    song.art        = [arts objectAtIndex: i];
    song.url        = [Song decryptURL: [urls objectAtIndex: i]];
    song.station_id = [station_ids objectAtIndex: i];
    song.music_id   = [music_ids objectAtIndex: i];
    song.user_seed  = [user_seeds objectAtIndex: i];
    song.rating     = [ratings objectAtIndex: i];
    song.song_type  = [song_types objectAtIndex: i];
    song.album_url  = [album_urls objectAtIndex: i];
    song.artist_url = [artist_urls objectAtIndex: i];
    song.title_url  = [title_urls objectAtIndex: i];

    [songs addObject: song];
  }

  xmlFreeDoc(doc);

  return songs;
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

  return [self sendRequest: @"sync" : [Crypt encrypt: xml]] != NULL;
}

/**
 * Rate a song, "0" = dislike, "1" = like
 */
- (BOOL) rateSong: (Song*) song : (NSString*) rating {
  xmlDocPtr doc;
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
     [self time], authToken, [song station_id], [song music_id],
       [song user_seed], @"undefined", rating, [song song_type]
   ];

  doc = [self sendRequest: @"station.addFeedback" : [Crypt encrypt: xml]];

  if (doc != NULL) {
    song.rating = rating;
  }

  return doc != NULL;
}

/**
 * Sends a request to the server and parses the response as XML
 */
- (xmlDocPtr) sendRequest: (NSString*)method : (NSString*)data {
  NSString *time = [NSString stringWithFormat:@"%d", [self time]];
  NSString *rid  = [time substringFromIndex: 3];

  NSString *url = [NSString stringWithFormat:
    @"http://www.pandora.com/radio/xmlrpc/v29?rid=%@P&method=%@", rid, method];

  if (![method isEqual: @"sync"] && ![method isEqual: @"authenticateListener"]) {
    NSString *lid = [NSString stringWithFormat:@"lid=%@", listenerID];
    url = [url stringByAppendingString:lid];
  }

  // Prepare the request
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

  [request setURL: [NSURL URLWithString:url]];
  [request setHTTPMethod: @"POST"];
  [request addValue: @"application/xml" forHTTPHeaderField: @"Content-Type"];

  // Create the body
  NSMutableData *postBody = [NSMutableData data];
  [postBody appendData: [data dataUsingEncoding:NSUTF8StringEncoding]];
  [request setHTTPBody:postBody];

  //get response
  NSHTTPURLResponse *urlResponse = nil;
  NSError *error = [[NSError alloc] init];
  NSData *responseData = [NSURLConnection sendSynchronousRequest:request
    returningResponse:&urlResponse error:&error];

  if ([urlResponse statusCode] < 200 || [urlResponse statusCode] >= 300) {
    responseData = nil;
  }

  [request release];
  [error release];

  if (responseData == nil) {
    return NULL;
  }

  xmlDocPtr doc = xmlReadMemory([responseData bytes], [responseData length], "",
    NULL, XML_PARSE_RECOVER);
  NSArray *fault = [self xpath: doc : "//methodResponse/fault"];

  if ([fault count] > 0) {
    NSString *resp = [[NSString alloc] initWithData:responseData
        encoding:NSASCIIStringEncoding];
    NSLog(@"Fault!: %@", resp);
    xmlFreeDoc(doc);
    return NULL;
  }

  return doc;
}

@end
