#import <AudioStreamer/ASPlaylist.h>

@class Pandora;
@class Song;

@interface Station : ASPlaylist<NSCoding> {
  BOOL shouldPlaySongOnFetch;

  NSMutableArray *songs;
  Pandora *radio;
}

@property NSString *name;
@property NSString *token;
@property NSString *stationId;
@property UInt32 created;
@property Song *playingSong;
@property BOOL shared;
@property BOOL allowRename;
@property BOOL allowAddMusic;

- (void) setRadio:(Pandora*)radio;
- (NSString*) streamNetworkError;

+ (Station*) stationForToken:(NSString*)token;
+ (void) addStation:(Station*)s;
+ (void) removeStation:(Station*)s;

@end
