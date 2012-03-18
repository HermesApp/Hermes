/**
 * @file Scrobbler.m
 * @brief Implementation of talking with last.fm
 *
 * Handles the serialization of requests to last.fm and handles all errors
 * associated with them. The errors are displayed to the user via popups,
 * which could probably use some poslishing...
 */

#import "Keychain.h"
#import "PreferencesController.h"
#import "Scrobbler.h"
#import "Station.h"
#import "SBJson.h"

#define LASTFM_KEYCHAIN_ITEM @"hermes-lastfm-sk"

/* Singleton instance of the Scrobbler class used globally */
static Scrobbler *subscriber = nil;
static FMCallback errorChecker;

@implementation Scrobbler

@synthesize engine, authToken, sessionToken;

/**
 * @brief Internal helper method to display an error message
 */
- (void) error: (NSString*) message {
  NSString *header = @"last.fm error: ";
  NSAlert *alert = [[NSAlert alloc] init];
  message = [header stringByAppendingString:message];
  [alert setMessageText:message];
  [alert addButtonWithTitle:@"OK"];
  [alert beginSheetModalForWindow:[[NSApp delegate] window]
                    modalDelegate:self
                   didEndSelector:nil
                      contextInfo:nil];
}

/**
 * @brief Creates a global instance of a Scrobbler, if necessary
 *
 * Also begins fetching of session keys for the last.fm API
 */
+ (void) subscribe {
  if (subscriber == nil) {
    subscriber = [[Scrobbler alloc] init];
    errorChecker = ^(NSData *data, NSError *error) {
      if (error != nil) {
        [subscriber error:[error localizedDescription]];
        return;
      }
      SBJsonParser *parser = [[SBJsonParser alloc] init];
      NSDictionary *object = [parser objectWithData:data];

      if ([object objectForKey:@"error"] != nil) {
        NSLogd(@"%@", object);
        [subscriber error:[object objectForKey:@"message"]];
      }
    };

    [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(songPlayed:)
             name:@"song.playing"
           object:nil];
  }
}

/**
 * @brief Deallocates the Scrobble singleton, cancelling all further
 *        API calls.
 */
+ (void) unsubscribe {
  subscriber = nil;
  errorChecker = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * @brief Helper method to send the method to the singleton.
 *
 * No action is performed if the singleton is nil
 */
+ (void) scrobble:(Song *)song state:(ScrobbleState)status {
  if (subscriber != nil) {
    [subscriber scrobble:song state:status];
  }
}

/**
 * @brief Helper used to listen to notifications about new songs
 */
+ (void) songPlayed:(NSNotification*) notification {
  Station *station = [notification object];
  Song *playing = [station playing];
  if (playing != nil) {
    if ([[playing rating] isEqualToString:@"1"]) {
      /* If a song is liked, then be sure we tell last.fm as such */
      [subscriber setPreference:playing loved:YES];
    }
    [subscriber scrobble:playing state:NewSong];
  }
}

/**
 * @brief Helper method to send the method to the singleton.
 *
 * No action is performed if the singleton is nil
 */
+ (void) setPreference: (Song*)song loved:(BOOL)loved {
  if (subscriber != nil) {
    [subscriber setPreference:song loved:loved];
  }
}

/**
 * @brief Initializes the Scrobbler instance, fetching the saved session token
 */
- (id) init {
  if ((self = [super init])) {
    [self setEngine:[[FMEngine alloc] init]];

    /* Try to get the saved session token, otherwise get a new one */
    NSString *str = KeychainGetPassword(LASTFM_KEYCHAIN_ITEM);
    if (str == nil || [@"" isEqual:str]) {
      NSLogd(@"No saved sesssion token for last.fm, fetching another");
      [self fetchAuthToken];
    } else {
      NSLogd(@"Found saved sessionn token found for last.fm");
      [self setSessionToken:str];
    }
  }

  return self;
}

- (void) dealloc {
  if (timer != nil && [timer isValid]) {
    [timer invalidate];
  }
}

/**
 * @brief Scrobbles a song to last.fm
 *
 * This can be used for any ScrobbleState, but should only be sent at the
 * appropriate time as per last.fm's guidelines.
 *
 * Assumes that the session token is already available, if not, the scrobble
 * is ignored under the assumption that the session token will come soon.
 *
 * @param song the song which is being scrobbled
 * @param status the playback state of the song
 */
- (void) scrobble:(Song *)song state:(ScrobbleState)status {
  /* If we don't have a sesion token yet, just ignore this for now */
  if (sessionToken == nil || [@"" isEqual:sessionToken] || song == nil) {
    return;
  }
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:ONLY_SCROBBLE_LIKED] &&
      ![[song rating] isEqualToString:@"1"]) {
    return;
  }

  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

  [dictionary setObject:sessionToken      forKey:@"sk"];
  [dictionary setObject:_LASTFM_API_KEY_  forKey:@"api_key"];
  [dictionary setObject:[song title]      forKey:@"track"];
  [dictionary setObject:[song artist]     forKey:@"artist"];
  [dictionary setObject:[song album]      forKey:@"album"];
  [dictionary setObject:[song musicId]    forKey:@"mbid"];
  [dictionary setObject:@"0"              forKey:@"chosenByUser"];

  NSNumber *time = [NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]];
  [dictionary setObject:time forKey:@"timestamp"];

  /* Relevant API documentation at
   *  - http://www.last.fm/api/show/track.scrobble
   *  - http://www.last.fm/api/show/track.updateNowPlaying
   */
  NSString *method = status == FinalStatus ? @"track.scrobble"
                                           : @"track.updateNowPlaying";
  [engine performMethod:method
           withCallback:errorChecker
         withParameters:dictionary
           useSignature:YES
             httpMethod:@"POST"];
}

/**
 * @brief Tell last.fm that a track is 'loved' or 'unloved'
 *
 * @param song the song to love
 * @param loved whether the song should be 'loved' or 'unloved'
 */
- (void) setPreference: (Song*)song loved:(BOOL)loved {
  /* If we don't have a sesion token yet, just ignore this for now */
  if (sessionToken == nil || [@"" isEqual:sessionToken] || song == nil) {
    return;
  }

  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

  [dictionary setObject:sessionToken      forKey:@"sk"];
  [dictionary setObject:_LASTFM_API_KEY_  forKey:@"api_key"];
  [dictionary setObject:[song title]      forKey:@"track"];
  [dictionary setObject:[song artist]     forKey:@"artist"];

  /* Relevant API documentation at http://www.last.fm/api/show/track.love */
  [engine performMethod:(loved ? @"track.love" : @"track.unloved")
           withCallback:errorChecker
         withParameters:dictionary
           useSignature:YES
             httpMethod:@"POST"];
}

/**
 * @brief Display a dialog saying that we need authorization from the user.
 *
 * If canceled, then last.fm is turned off. Otherwise, when confirmed, the user
 * is redirected to a page to approve Hermes. We give them a bit to do this
 * and then we automatically retry to get the authorization token
 */
- (void) needAuthorization {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:@"Hermes needs authorization to scrobble on last.fm"];
  [alert addButtonWithTitle:@"OK"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert beginSheetModalForWindow:[[NSApp delegate] window]
                    modalDelegate:self
                   didEndSelector:@selector(openAuthorization:returnCode:contextInfo:)
                      contextInfo:nil];
}

/**
 * @brief Callback for when the user closes the 'need authorization' dialog
 *
 * Implementation of the dialog's delegate
 */
- (void) openAuthorization:(NSAlert *)alert
                returnCode:(NSInteger)returnCode
               contextInfo:(void *)contextInfo {
  if (returnCode != NSAlertFirstButtonReturn) {
    return;
  }

  NSString *authURL = [NSString stringWithFormat:
                       @"http://www.last.fm/api/auth/?api_key=%@&token=%@",
                       _LASTFM_API_KEY_, authToken];
  NSURL *url = [NSURL URLWithString:authURL];

  [[NSWorkspace sharedWorkspace] openURL:url];

  /* Give the user some time to give us permission. Then try to get the session
     key again */
  timer = [NSTimer scheduledTimerWithTimeInterval:20
                                  target:self
                                selector:@selector(fetchSessionToken)
                                userInfo:nil
                                 repeats:NO];
}

/**
 * @brief Fetch an authorization token
 *
 * This is then used to get a session token via callbacks.
 */
- (void) fetchAuthToken {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:_LASTFM_API_KEY_ forKey:@"api_key"];

  /* More info at http://www.last.fm/api/show/auth.getToken */
  FMCallback cb = ^(NSData *data, NSError *error) {
    if (error != nil) {
      [self error:[error localizedDescription]];
      return;
    }
    SBJsonParser *parser = [[SBJsonParser alloc] init];

    NSDictionary *object = [parser objectWithData:data];

    [self setAuthToken:[object objectForKey:@"token"]];

    if (authToken == nil || [@"" isEqual:authToken]) {
      [self setAuthToken:nil];
      [self error:@"Couldn't get an auth token from last.fm!"];
    } else {
      [self fetchSessionToken];
    }
  };

  [engine performMethod:@"auth.getToken"
           withCallback:cb
         withParameters:dict
           useSignature:YES
             httpMethod:@"GET"];
}

/**
 * @brief Fetch a session token for a logged in user
 *
 * This will generate an error if they haven't approved our authentication
 * token, but then we ask them to approve it and we retry with the same
 * authorization token.
 */
- (void) fetchSessionToken {
  NSLogd(@"Fetching session token for last.fm...");
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:_LASTFM_API_KEY_ forKey:@"api_key"];
  [dict setObject:authToken forKey:@"token"];

  /* More info at http://www.last.fm/api/show/auth.getSession */
  FMCallback cb = ^(NSData *data, NSError *error) {
    if (error != nil) {
      [self error:[error localizedDescription]];
      return;
    }
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSDictionary *object = [parser objectWithData:data];

    if ([object objectForKey:@"error"] != nil) {
      NSNumber *code = [object objectForKey:@"error"];

      if ([code intValue] == 14) {
        [self needAuthorization];
      } else {
        [self error:[object objectForKey:@"message"]];
      }
      [self setSessionToken:nil];
      return;
    }

    NSDictionary *session = [object objectForKey:@"session"];
    [self setSessionToken:[session objectForKey:@"key"]];
    if (!KeychainSetItem(LASTFM_KEYCHAIN_ITEM, sessionToken)) {
      [self error:@"Couldn't save session token to keychain!"];
    }
  };

  [engine performMethod:@"auth.getSession"
           withCallback:cb
         withParameters:dict
           useSignature:YES
             httpMethod:@"GET"];
}

@end
