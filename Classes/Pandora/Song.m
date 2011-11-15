#import "Song.h"
#import "Crypt.h"

@implementation Song

@synthesize artist, title, album, url, stationId, musicId, userSeed, rating,
  songType, albumUrl, artistUrl, titleUrl, art;

- (id) initWithCoder: (NSCoder *)coder {
  if ((self = [super init])) {
    [self setArtist:[coder decodeObjectForKey:@"artist"]];
    [self setTitle:[coder decodeObjectForKey:@"title"]];
    [self setAlbum:[coder decodeObjectForKey:@"album"]];
    [self setArt:[coder decodeObjectForKey:@"art"]];
    [self setUrl:[coder decodeObjectForKey:@"url"]];
    [self setStationId:[coder decodeObjectForKey:@"stationId"]];
    [self setMusicId:[coder decodeObjectForKey:@"musicId"]];
    [self setUserSeed:[coder decodeObjectForKey:@"userSeed"]];
    [self setRating:[coder decodeObjectForKey:@"rating"]];
    [self setSongType:[coder decodeObjectForKey:@"songType"]];
    [self setAlbumUrl:[coder decodeObjectForKey:@"albumUrl"]];
    [self setArtistUrl:[coder decodeObjectForKey:@"artistUrl"]];
    [self setTitleUrl:[coder decodeObjectForKey:@"titleUrl"]];
  }
  return self;
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

- (void) encodeWithCoder: (NSCoder *)coder {
  [coder encodeObject: artist forKey:@"artist"];
  [coder encodeObject: title forKey:@"title"];
  [coder encodeObject: album forKey:@"album"];
  [coder encodeObject: art forKey:@"art"];
  [coder encodeObject: url forKey:@"url"];
  [coder encodeObject: stationId forKey:@"stationId"];
  [coder encodeObject: musicId forKey:@"musicId"];
  [coder encodeObject: userSeed forKey:@"userSeed"];
  [coder encodeObject: rating forKey:@"rating"];
  [coder encodeObject: songType forKey:@"songType"];
  [coder encodeObject: albumUrl forKey:@"albumUrl"];
  [coder encodeObject: artistUrl forKey:@"artistUrl"];
  [coder encodeObject: titleUrl forKey:@"titleUrl"];
}

@end
