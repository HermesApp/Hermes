@class Station;

@interface Song : NSObject <NSCoding>

@property(nonatomic, retain) NSString *artist;
@property(nonatomic, retain) NSString *title;
@property(nonatomic, retain) NSString *album;
@property(nonatomic, retain) NSString *art;
@property(nonatomic, retain) NSString *stationId;
@property(nonatomic, retain) NSNumber *nrating;
@property(nonatomic, retain) NSString *albumUrl;
@property(nonatomic, retain) NSString *artistUrl;
@property(nonatomic, retain) NSString *titleUrl;
@property(nonatomic, retain) NSString *token;

@property(nonatomic, retain) NSString *highUrl;
@property(nonatomic, retain) NSString *medUrl;
@property(nonatomic, retain) NSString *lowUrl;

@property(nonatomic, retain) NSDate *playDate;
@property(readonly) NSString *playDateString;

- (NSDictionary*) toDictionary;
- (BOOL) isEqual:(id)other;
- (Station*) station;

@end
