//
//  Authenticator.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

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

/* Wrapper for requests to retry against authentication */
@interface RetryRequest : NSObject {
  SEL callback;
  id  payload1;
  id  payload2;
}

@property (readwrite) SEL callback;
@property (retain) id payload1;
@property (retain) id payload2;

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
- (BOOL) authenticate: (NSString*)user :(NSString*)pass : (RetryRequest*) req;
- (BOOL) authenticated;
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
