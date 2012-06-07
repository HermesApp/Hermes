/**
 * @file Scrobbler.h
 *
 * @brief Interface for talking to last.fm's api and updating what's currently
 *        being listened to and such.
 */

#import "FMEngine.h"
#import "Song.h"

typedef enum scrobblestate {
  NewSong,
  NowPlaying,
  FinalStatus
} ScrobbleState;

#define SCROBBLER [[NSApp delegate] scrobbler]

@interface Scrobbler : NSObject {
  FMEngine *engine;
  NSString *authToken;
  NSString *sessionToken;
  NSTimer *timer;
  FMCallback errorChecker;
}

- (void) fetchAuthToken;
- (void) fetchSessionToken;
- (void) setPreference: (Song*)song loved:(BOOL)loved;
- (void) scrobble: (Song*) song state: (ScrobbleState) status;

@end
