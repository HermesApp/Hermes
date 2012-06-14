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
  NSString *name;
  NSString *stationId;
  NSString *token;
  NSMutableArray *songs;
  Pandora *radio;
  AudioStreamer *stream;
  Song *playing;
  NSTimer *waitingTimeout;
}

@property (retain) NSString *name;
@property (retain) NSString *token;
@property (retain) NSString *stationId;
@property (retain) Song *playing;

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
- (double) duration;
- (double) progress;

/* Managing songs */
- (void) clearSongList;

@end
