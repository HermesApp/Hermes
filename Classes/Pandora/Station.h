@class Pandora;
@class Song;
@class AudioStreamer;

@interface Station : NSObject<NSCoding> {
  BOOL shouldPlaySongOnFetch;
  BOOL retrying;
  BOOL nexting;
  BOOL volumeSet;
  double lastKnownSeekTime;
  double volume;

  NSInteger tries;
  NSMutableArray *songs;
  Pandora *radio;
  AudioStreamer *stream;
}

@property NSString *name;
@property NSString *token;
@property NSString *stationId;
@property Song *playing;
@property BOOL shared;
@property BOOL allowRename;
@property BOOL allowAddMusic;

- (void) next;
- (void) retry:(BOOL)countTries;
- (void) setRadio: (Pandora*) radio;
- (BOOL) isEqual:(id)object;
- (void) fetchMoreSongs;
- (void) copyFrom: (Station*) other;

/* Interface to AudioStreamer */
- (BOOL) isPaused;
- (BOOL) isPlaying;
- (BOOL) isIdle;
- (BOOL) isError;
- (void) play;
- (void) pause;
- (void) stop;
- (void) setVolume:(double)volume;
- (NSString*) streamNetworkError;
- (BOOL) duration:(double*)ret;
- (BOOL) progress:(double*)ret;

/* Managing songs */
- (void) clearSongList;

@end
