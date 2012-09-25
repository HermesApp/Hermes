@class Station;

@interface Song : NSObject <NSCoding>

@property NSString *artist;
@property NSString *title;
@property NSString *album;
@property NSString *art;
@property NSString *stationId;
@property NSNumber *nrating;
@property NSString *albumUrl;
@property NSString *artistUrl;
@property NSString *titleUrl;
@property NSString *token;

@property NSString *highUrl;
@property NSString *medUrl;
@property NSString *lowUrl;
@property (unsafe_unretained) Station *station;

+ (NSString*) decryptURL: (NSString*) url;
- (NSDictionary*) toDictionary;
- (BOOL) isEqual:(id)other;

@end
