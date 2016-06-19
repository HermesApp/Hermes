#import "Song.h"
#import "Station.h"
#import "Crypt.h"

@implementation Song

@synthesize artist, title, album, highUrl, stationId, nrating,
  albumUrl, artistUrl, titleUrl, art, token, medUrl, lowUrl, playDate;

#pragma mark - NSObject

- (BOOL) isEqual:(id)object {
  return [token isEqual:[object token]];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p %@ - %@>", NSStringFromClass(self.class), self, self.artist, self.title];
}

#pragma mark - NSCoding

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
    [self setPlayDate:[coder decodeObjectForKey:@"playDate"]];
  }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder {
  NSDictionary *info = [self toDictionary];
  for(id key in info) {
    [coder encodeObject:info[key] forKey:key];
  }
}

#pragma mark - NSDistributedNotification user info

- (NSDictionary*) toDictionary {
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  [info setValue:artist forKey:@"artist"];
  [info setValue:title forKey:@"title"];
  [info setValue:album forKey:@"album"];
  [info setValue:art forKey:@"art"];
  [info setValue:lowUrl forKey:@"lowUrl"];
  [info setValue:medUrl forKey:@"medUrl"];
  [info setValue:highUrl forKey:@"highUrl"];
  [info setValue:stationId forKey:@"stationId"];
  [info setValue:nrating forKey:@"nrating"];
  [info setValue:albumUrl forKey:@"albumUrl"];
  [info setValue:artistUrl forKey:@"artistUrl"];
  [info setValue:titleUrl forKey:@"titleUrl"];
  [info setValue:token forKey:@"token"];
  [info setValue:playDate forKey:@"playDate"];
  return info;
}

#pragma mark - Object Specifier

- (NSScriptObjectSpecifier *) objectSpecifier {
  NSScriptClassDescription *containerClassDesc =
  [NSScriptClassDescription classDescriptionForClass:[Station class]];

  return [[NSNameSpecifier alloc]
          initWithContainerClassDescription:containerClassDesc
          containerSpecifier:nil key:@"songs" name:[self title]];
}

#pragma mark - Reference to station

- (Station*) station {
  return [Station stationForToken:[self stationId]];
}

#pragma mark - Formatted play date

- (NSString *)playDateString {
  if (self.playDate == nil)
    return nil;

  static NSDateFormatter *songDateFormatter = nil;
  if (songDateFormatter == nil) {
    songDateFormatter = [[NSDateFormatter alloc] init];
    songDateFormatter.dateStyle = NSDateFormatterShortStyle;
    songDateFormatter.timeStyle = NSDateFormatterShortStyle;
    songDateFormatter.doesRelativeDateFormatting = YES;
  }

  return [songDateFormatter stringFromDate:playDate];
}

@end
