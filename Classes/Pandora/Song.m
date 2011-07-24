#import "Song.h"
#import "Crypt.h"

@implementation Song

@synthesize artist, title, album, url, stationId, musicId, userSeed, rating,
  songType, albumUrl, artistUrl, titleUrl, art;

- (void) dealloc {
  [artist release];
  [title release];
  [album release];
  [art release];
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
