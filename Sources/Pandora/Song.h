@class Station;

@interface Song : NSObject <NSCoding>

@property(nonatomic, assign) NSString *artist;
@property(nonatomic, assign) NSString *title;
@property(nonatomic, assign) NSString *album;
@property(nonatomic, assign) NSString *art;
@property(nonatomic, assign) NSString *stationId;
@property(nonatomic, assign) NSNumber *nrating;
@property(nonatomic, assign) NSString *albumUrl;
@property(nonatomic, assign) NSString *artistUrl;
@property(nonatomic, assign) NSString *titleUrl;
@property(nonatomic, assign) NSString *token;

@property(nonatomic, assign) NSString *highUrl;
@property(nonatomic, assign) NSString *medUrl;
@property(nonatomic, assign) NSString *lowUrl;

- (NSDictionary*) toDictionary;
- (BOOL) isEqual:(id)other;
- (Station*) station;

@end
