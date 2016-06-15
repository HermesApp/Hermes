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
@property unsigned long long created;
@property Song *playingSong;
@property BOOL shared;
@property BOOL allowRename;
@property BOOL allowAddMusic; // seems that (with the exception of QuickMix, which is excluded from editing elsewhere) that this is not actually a limitation any more; it's possible to add seeds to genre stations (#267).
@property BOOL isQuickMix;

- (void) setRadio:(Pandora*)radio;
- (NSString*) streamNetworkError;

+ (Station*) stationForToken:(NSString*)token;
+ (void) addStation:(Station*)s;
+ (void) removeStation:(Station*)s;

@end
