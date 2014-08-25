#import "Song.h"
#import "Station.h"
#import "Crypt.h"

@implementation Song

#pragma mark - NSObject

- (BOOL) isEqual:(id)object {
  return [self.token isEqual:[object token]];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p %@ - %@>",
          NSStringFromClass(self.class),
          self,
          self.artist,
          self.title];
}

#pragma mark - NSCoding

- (id) initWithCoder: (NSCoder *)coder {
  if ((self = [super init])) {
    self.title         = [coder decodeObjectForKey:@"title"];
    self.artist        = [coder decodeObjectForKey:@"artist"];
    self.album         = [coder decodeObjectForKey:@"album"];
    self.art           = [coder decodeObjectForKey:@"art"];
    self.nrating       = [coder decodeObjectForKey:@"nrating"];
    self.stationId     = [coder decodeObjectForKey:@"stationId"];
    self.token         = [coder decodeObjectForKey:@"token"];
    self.advertisement = [coder decodeObjectForKey:@"advertisement"];
    self.titleUrl      = [coder decodeObjectForKey:@"titleUrl"];
    self.artistUrl     = [coder decodeObjectForKey:@"artistUrl"];
    self.albumUrl      = [coder decodeObjectForKey:@"albumUrl"];
    self.lowUrl        = [coder decodeObjectForKey:@"lowUrl"];
    self.medUrl        = [coder decodeObjectForKey:@"medUrl"];
    self.highUrl       = [coder decodeObjectForKey:@"highUrl"];
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
  return @{
           @"title":         self.title,
           @"artist":        self.artist,
           @"album":         self.album,
           @"art":           self.art,
           @"nrating":       self.nrating,
           @"stationId":     self.stationId,
           @"token":         self.token,
           @"advertisement": self.advertisement,
           @"titleUrl":      self.titleUrl,
           @"artistUrl":     self.artistUrl,
           @"albumUrl":      self.albumUrl,
           @"lowUrl":        self.lowUrl,
           @"medUrl":        self.medUrl,
           @"highUrl":       self.highUrl,
           };
}

#pragma mark - Object Specifier

- (NSScriptObjectSpecifier *) objectSpecifier {
  NSScriptClassDescription *containerClassDesc = [NSScriptClassDescription
                                                  classDescriptionForClass:[Station class]];

  return [[NSNameSpecifier alloc] initWithContainerClassDescription:containerClassDesc
                                                 containerSpecifier:nil
                                                                key:@"songs"
                                                               name:self.title];
}

#pragma mark - Reference to station

- (Station*) station {
  return [Station stationForToken:self.stationId];
}

@end
