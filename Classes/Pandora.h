//
//  Authenticator.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Song.h"
#import "API.h"

@interface SearchResult : NSObject {
  NSString *name;
  NSString *value;
}

@property (retain) NSString *name;
@property (retain) NSString *value;

@end

@interface Pandora : API {
  NSString *authToken;
  NSMutableArray *stations;
}

@property (retain) NSString* authToken;
@property (retain) NSArray* stations;

- (BOOL) authenticate: (NSString*)user :(NSString*)pass;
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
