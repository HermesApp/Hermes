//
//  Scrobbler.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "FMEngine.h"
#import "Song.h"

@interface Scrobbler : NSObject {
  FMEngine *engine;
  NSString *authToken;
  NSString *sessionToken;
  NSTimer *timer;
}

typedef enum scrobblestate {
    NewSong,
    NowPlaying,
    FinalStatus
} ScrobbleState;
+ (void) subscribe;
+ (void) unsubscribe;
+ (void) scrobble: (Song*) song state: (ScrobbleState) status;

@property (retain) FMEngine *engine;
@property (retain) NSString *authToken;
@property (retain) NSString *sessionToken;

- (void) fetchAuthToken;
- (void) fetchSessionToken;
- (void) scrobble: (Song*) song state: (ScrobbleState) status;

@end
