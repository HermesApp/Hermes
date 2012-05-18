@interface Song : NSObject <NSCoding> {
  NSString *artist;
  NSString *title;
  NSString *album;
  NSString *art;
  NSString *stationId;
  NSNumber *nrating;
  NSString *albumUrl;
  NSString *artistUrl;
  NSString *titleUrl;
  NSString *token;

  NSString *highUrl;
  NSString *medUrl;
  NSString *lowUrl;
  NSString *stationToken;
}

@property (retain) NSString *artist;
@property (retain) NSString *title;
@property (retain) NSString *album;
@property (retain) NSString *art;
@property (retain) NSString *stationId;
@property (retain) NSNumber *nrating;
@property (retain) NSString *albumUrl;
@property (retain) NSString *artistUrl;
@property (retain) NSString *titleUrl;
@property (retain) NSString *token;

@property (retain) NSString *highUrl;
@property (retain) NSString *medUrl;
@property (retain) NSString *lowUrl;
@property (retain) NSString *stationToken;

+ (NSString*) decryptURL: (NSString*) url;
- (NSDictionary*) toDictionary;

@end
