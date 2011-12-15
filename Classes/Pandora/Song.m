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
  /* Last 16 bytes of the URL are encrypted */
  char buf[17];
  int index = [url length] - 48;

  NSString *pref = [url substringToIndex: index];
  NSData *data = PandoraDecrypt([url substringFromIndex: index]);
  strncpy(buf, [data bytes], sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = 0;
  NSString *suff = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];

  return [pref stringByAppendingString:suff];
}

- (NSDictionary*) toDictionary {
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  [info setValue: artist forKey:@"artist"];
  [info setValue: title forKey:@"title"];
  [info setValue: album forKey:@"album"];
  [info setValue: art forKey:@"art"];
  [info setValue: url forKey:@"url"];
  [info setValue: stationId forKey:@"stationId"];
  [info setValue: musicId forKey:@"musicId"];
  [info setValue: userSeed forKey:@"userSeed"];
  [info setValue: rating forKey:@"rating"];
  [info setValue: songType forKey:@"songType"];
  [info setValue: albumUrl forKey:@"albumUrl"];
  [info setValue: artistUrl forKey:@"artistUrl"];
  [info setValue: titleUrl forKey:@"titleUrl"];
  return info;
}

- (void) encodeWithCoder: (NSCoder *)coder {
  NSDictionary *info = [self toDictionary];
  for(id key in info) {
    [coder encodeObject:[info objectForKey:key] forKey:key];
  }
}

@end
