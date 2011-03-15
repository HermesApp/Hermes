//
//  Song.h
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

@interface Song : NSObject {

}

@property (retain) NSString *artist;
@property (retain) NSString *title;
@property (retain) NSString *art;
@property (retain) NSString *url;
@property (retain) NSString *station_id;
@property (retain) NSString *music_id;
@property (retain) NSString *user_seed;
@property (retain) NSString *rating;
@property (retain) NSString *song_type;
@property (retain) NSString *album_url;
@property (retain) NSString *artist_url;
@property (retain) NSString *title_url;

+ (NSString*) decryptURL: (NSString*) url;

@end
