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

@interface Scrobbler : NSObject {
  FMEngine *engine;
  NSString *authToken;
  NSString *sessionToken;
  NSTimer *timer;
}

+ (void) subscribe;
+ (void) unsubscribe;
+ (void) setPreference: (Song*)song loved:(BOOL)loved;
+ (void) scrobble: (Song*) song state: (ScrobbleState) status;

@property (retain) FMEngine *engine;
@property (retain) NSString *authToken;
@property (retain) NSString *sessionToken;

- (void) fetchAuthToken;
- (void) fetchSessionToken;
- (void) setPreference: (Song*)song loved:(BOOL)loved;
- (void) scrobble: (Song*) song state: (ScrobbleState) status;

@end
