//
//  Authenticator.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Song.h"
#import "API.h"

@interface Pandora : API {
  NSString *authToken;
  NSMutableArray *stations;
}

@property (retain) NSString* authToken;
@property (retain) NSArray* stations;

- (BOOL) authenticate: (NSString*)user :(NSString*)pass;
- (BOOL) fetchStations;
- (NSArray*) getFragment: (NSString*)station_id;
- (BOOL) sync;
- (BOOL) rateSong: (Song*)song : (NSString*)rating;
- (BOOL) tiredOfSong: (Song*)song;

@end
