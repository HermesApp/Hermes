//
//  Song.m
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Song.h"
#import "Crypt.h"

@implementation Song

@synthesize artist, title, album, art, url, stationId, musicId, userSeed, rating,
  songType, albumUrl, artistUrl, titleUrl, otherArt;

- (void) dealloc {
  [artist release];
  [title release];
  [album release];
  [art release];
  [otherArt release];
  [url release];
  [stationId release];
  [musicId release];
  [userSeed release];
  [rating release];
  [songType release];
  [albumUrl release];
  [artistUrl release];
  [titleUrl release];

  [super dealloc];
}

- (void) setArt:(NSString*)a {
  art = [a stringByReplacingOccurrencesOfString:@"130W_130H"
      withString:@"500W_500H"];

  otherArt = a;
  [otherArt retain];
  [art retain];
}

/**
 * Decrypts the URL received from Pandora
 */
+ (NSString*) decryptURL: (NSString*) url {
  int index = [url length] - 48;

  NSString *pref = [url substringToIndex: index];
  NSString *suff = PandoraDecrypt([url substringFromIndex: index]);

  return [pref stringByAppendingString: suff];
}

@end
