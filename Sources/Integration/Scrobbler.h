/**
 * @file Scrobbler.h
 *
 * @brief Interface for talking to last.fm's api and updating what's currently
 *        being listened to and such.
 */

#import "FMEngine/FMEngine.h"
#import "Pandora/Song.h"

typedef enum {
  NewSong,
  NowPlaying,
  FinalStatus
} ScrobbleState;

#define SCROBBLER [[NSApp delegate] scrobbler]

@class SBJsonParser;

@interface Scrobbler : NSObject {
  FMEngine *engine;
  NSString *authToken;
  NSString *isAlreadyAuth;
  NSString *sessionToken;
  NSTimer *timer;
  SBJsonParser *parser;
}

- (void) setPreference: (Song*)song loved:(BOOL)loved;
- (void) scrobble: (Song*) song state: (ScrobbleState) status;

@end
