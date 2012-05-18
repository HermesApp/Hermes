#import "Pandora.h"
#import "AudioStreamer.h"
#import "Song.h"

@interface Station : NSObject<NSCoding> {
  BOOL shouldPlaySongOnFetch;
  BOOL retrying;
  double lastKnownSeekTime;

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
@property (retain) NSMutableArray *songs;
@property (retain) AudioStreamer *stream;
@property (retain) Song *playing;

- (void) play;
- (void) next;
- (void) pause;
- (void) stop;
- (void) retry;
- (BOOL) isPaused;
- (void) setRadio: (Pandora*) radio;
- (BOOL) isEqual:(id)object;
- (void) fetchMoreSongs;
- (void) copyFrom: (Station*) other;

@end
