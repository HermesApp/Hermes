//
//  Authenticator.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <libxml/parser.h>
#import "Station.h"
#import "Song.h"

@interface Pandora : NSObject {
  NSString *authToken;
  NSString *listenerID;
  NSMutableArray *stations;
  NSMutableArray *songs;
}

@property (retain) NSString* authToken;
@property (retain) NSString* listenerID;
@property (retain) NSArray* stations;

- (void) authenticate: (NSString*)user :(NSString*)pass;
- (void) fetchStations;
- (void) playStation: (Station*) station;
- (xmlDocPtr) sendRequest: (NSString*)method :(NSString*)data;

@end
