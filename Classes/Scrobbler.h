#import "FMEngine.h"
#import "Song.h"

@interface Scrobbler : NSObject {
  FMEngine *engine;
  NSString *authToken;
  NSString *sessionToken;
  NSTimer *timer;
}

+ (void) subscribe;
+ (void) unsubscribe;
+ (void) scrobble: (Song*) song;

@property (retain) FMEngine *engine;
@property (retain) NSString *authToken;
@property (retain) NSString *sessionToken;

- (void) fetchAuthToken;
- (void) fetchSessionToken;
- (void) scrobble: (Song*) song;

@end
