//
//  Song.h
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

@interface Song : NSObject {
  NSString *artist;
  NSString *title;
  NSString *album;
  NSString *art;
  NSString *otherArt;
  NSString *url;
  NSString *stationId;
  NSString *musicId;
  NSString *userSeed;
  NSString *rating;
  NSString *songType;
  NSString *albumUrl;
  NSString *artistUrl;
  NSString *titleUrl;
}

@property (retain) NSString *artist;
@property (retain) NSString *title;
@property (retain) NSString *album;
@property (retain) NSString *art;
@property (retain) NSString *otherArt;
@property (retain) NSString *url;
@property (retain) NSString *stationId;
@property (retain) NSString *musicId;
@property (retain) NSString *userSeed;
@property (retain) NSString *rating;
@property (retain) NSString *songType;
@property (retain) NSString *albumUrl;
@property (retain) NSString *artistUrl;
@property (retain) NSString *titleUrl;

+ (NSString*) decryptURL: (NSString*) url;

@end
