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

typedef enum status {
    NewSong,
    NowPlaying,
    FinalStatus
} Status;
+ (void) subscribe;
+ (void) unsubscribe;
+ (void) scrobble: (Song*) song status: (Status) status;

@property (retain) FMEngine *engine;
@property (retain) NSString *authToken;
@property (retain) NSString *sessionToken;

- (void) fetchAuthToken;
- (void) fetchSessionToken;
- (void) scrobble: (Song*) song status: (Status) status;

@end
