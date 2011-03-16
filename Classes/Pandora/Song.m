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

@synthesize artist, title, art, url, stationId, musicId, userSeed, rating,
  songType, albumUrl, artistUrl, titleUrl;

/**
 * Decrypts the URL received from Pandora
 */
+ (NSString*) decryptURL: (NSString*) url {
  int index = [url length] - 48;

  NSString *pref = [url substringToIndex: index];
  NSString *suff = [Crypt decrypt: [url substringFromIndex: index]];

  return [pref stringByAppendingString: suff];
}

@end
