#import "Song.h"
#import "Station.h"
#import "Crypt.h"

@implementation Song

@synthesize artist, title, album, highUrl, stationId, nrating,
  albumUrl, artistUrl, titleUrl, art, token, medUrl, lowUrl, station;

- (id) initWithCoder: (NSCoder *)coder {
  if ((self = [super init])) {
    [self setArtist:[coder decodeObjectForKey:@"artist"]];
    [self setTitle:[coder decodeObjectForKey:@"title"]];
    [self setAlbum:[coder decodeObjectForKey:@"album"]];
    [self setArt:[coder decodeObjectForKey:@"art"]];
    [self setHighUrl:[coder decodeObjectForKey:@"highUrl"]];
    [self setMedUrl:[coder decodeObjectForKey:@"medUrl"]];
    [self setLowUrl:[coder decodeObjectForKey:@"lowUrl"]];
    [self setStationId:[coder decodeObjectForKey:@"stationId"]];
    [self setNrating:[coder decodeObjectForKey:@"nrating"]];
    [self setAlbumUrl:[coder decodeObjectForKey:@"albumUrl"]];
    [self setArtistUrl:[coder decodeObjectForKey:@"artistUrl"]];
    [self setTitleUrl:[coder decodeObjectForKey:@"titleUrl"]];
    [self setToken:[coder decodeObjectForKey:@"token"]];
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
  NSString *suff = @(buf);
  NSLogd(@"%@", pref);

  return [pref stringByAppendingString:suff];
}

- (NSDictionary*) toDictionary {
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  [info setValue: artist forKey:@"artist"];
  [info setValue: title forKey:@"title"];
  [info setValue: album forKey:@"album"];
  [info setValue: art forKey:@"art"];
  [info setValue: lowUrl forKey:@"lowUrl"];
  [info setValue: medUrl forKey:@"medUrl"];
  [info setValue: highUrl forKey:@"highUrl"];
  [info setValue: stationId forKey:@"stationId"];
  [info setValue: nrating forKey:@"nrating"];
  [info setValue: albumUrl forKey:@"albumUrl"];
  [info setValue: artistUrl forKey:@"artistUrl"];
  [info setValue: titleUrl forKey:@"titleUrl"];
  [info setValue: token forKey:@"token"];
  return info;
}

- (void) encodeWithCoder: (NSCoder *)coder {
  NSDictionary *info = [self toDictionary];
  for(id key in info) {
    [coder encodeObject:info[key] forKey:key];
  }
}

- (NSScriptObjectSpecifier *) objectSpecifier {
  NSScriptClassDescription *containerClassDesc =
  [NSScriptClassDescription classDescriptionForClass:[Station class]];

  return [[NSNameSpecifier alloc]
          initWithContainerClassDescription:containerClassDesc
          containerSpecifier:nil key:@"songs" name:[self title]];
}

- (BOOL) isEqual:(id)object {
  return [token isEqual:[object token]];
}

@end
