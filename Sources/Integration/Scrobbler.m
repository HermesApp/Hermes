/**
 * @file Scrobbler.m
 * @brief Implementation of talking with last.fm
 *
 * Handles the serialization of requests to last.fm and handles all errors
 * associated with them. The errors are displayed to the user via popups,
 * which could probably use some polishing...
 */

#import "Keychain.h"
#import "PreferencesController.h"
#import "Scrobbler.h"
#import "Pandora/Station.h"
#import "Notifications.h"

#define LASTFM_KEYCHAIN_ITEM @"hermes-lastfm-sk"

@implementation Scrobbler

/**
 * @brief Creates a global instance of a Scrobbler, if necessary
 *
 * Also begins fetching of session keys for the last.fm API
 */
- (id) init {
  if (!(self = [super init])) { return self; }

  engine = [[FMEngine alloc] init];
  sessionToken = KeychainGetPassword(LASTFM_KEYCHAIN_ITEM);
  isAlreadyAuth = @"1";
  if ([@"" isEqualToString:sessionToken]) {
    sessionToken = nil;
    isAlreadyAuth = nil;
  }

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(songPlayed:)
           name:StationDidPlaySongNotification
         object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(songRated:)
           name:PandoraDidRateSongNotification
         object:nil];
  return self;
}

- (void) dealloc {
  if (timer != nil && [timer isValid]) {
    [timer invalidate];
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

typedef void(^ScrobblerCallback)(NSDictionary*);

/**
 * @brief Generates a callback for the FMEngine to handle errors
 *
 * @param callback the callback to be invoked with the parsed JSON object if
 *        the JSON was received without error and parsed without error
 * @param handles if YES, then the callback will always be invoked with valid
 *        JSON, otherwise if the json contains a last.fm error, the error will
 *        be handled here and the callback will not be invoked.
 */
- (FMCallback) errorChecker:(ScrobblerCallback)callback
              handlesErrors:(BOOL) handles {
  return ^(NSData *data, NSError *error) {
    /* If this is a network error, then this doesn't need to result in an
     * annoying popup dialog saying so. This entire app depends on the network
     * so everyone will know soon enough that the network is down */
    if (error != nil) {
      return;
    }

    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:nil error:&error];

    /* If this is a last.fm error, however, then this is a serious issue which
     * may need to be addressed manually, so do display a dialog here */
    if (error != nil) {
      [self error:[error localizedDescription]];
    } else if (!handles && object[@"error"] != nil) {
      /* Ignore temporary errors */
      if ([object[@"error"] intValue] != 16) {
        [self error:object[@"message"]];
      }
    } else {
      callback(object);
    }
  };
}

/**
 * @brief Callback for when a new songs plays (initializes scrobbling)
 */
- (void) songPlayed:(NSNotification*) not {
  Station *station = [not object];
  Song *playing = [station playingSong];
  if (playing != nil) {
    [self scrobble:playing state:NewSong];
  }
}

/**
 * @brief Callback for when a song is rated
 */
- (void) songRated:(NSNotification*) not {
  Song *song = [not userInfo][@"song"];
  if (song) {
    [self setPreference:song loved:([[song nrating] intValue] == 1)];
  }
}

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
  if (!PREF_KEY_BOOL(PLEASE_SCROBBLE) ||
      (PREF_KEY_BOOL(ONLY_SCROBBLE_LIKED) && [[song nrating] intValue] != 1)) {
    return;
  }
  if (sessionToken == nil) {
    [self fetchSessionToken];
    /* just lose this scrobble, it's not mission critical anyway */
    return;
  }

  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  dictionary[@"sk"] = sessionToken;
  dictionary[@"api_key"] = _LASTFM_API_KEY_;
  dictionary[@"track"] = [song title];
  dictionary[@"artist"] = [song artist];
  dictionary[@"album"] = [song album];
  dictionary[@"chosenByUser"] = @"0";

  NSNumber *time = @((UInt64) [[NSDate date] timeIntervalSince1970]);
  dictionary[@"timestamp"] = time;

  /* Relevant API documentation at
   *  - http://www.last.fm/api/show/track.scrobble
   *  - http://www.last.fm/api/show/track.updateNowPlaying
   */
  NSString *method = status == FinalStatus ? @"track.scrobble"
                                           : @"track.updateNowPlaying";
  [engine performMethod:method
           withCallback:[self errorChecker:^(NSDictionary *_){}
                             handlesErrors:NO]
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
  if (!PREF_KEY_BOOL(PLEASE_SCROBBLE) || !PREF_KEY_BOOL(PLEASE_SCROBBLE_LIKES)){
    return;
  }
  if (sessionToken == nil) {
    /* As above, it's "OK" if we drop this and just fetch a token for now */
    [self fetchSessionToken];
    return;
  }

  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

  dictionary[@"sk"] = sessionToken;
  dictionary[@"api_key"] = _LASTFM_API_KEY_;
  dictionary[@"track"] = [song title];
  dictionary[@"artist"] = [song artist];

  /* Relevant API documentation at http://www.last.fm/api/show/track.love */
  [engine performMethod:(loved ? @"track.love" : @"track.unlove")
           withCallback:[self errorChecker:^(NSDictionary *_){}
                             handlesErrors:NO]
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
                                selector:@selector(fetchSessionTokenAlready)
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
  dict[@"api_key"] = _LASTFM_API_KEY_;

  /* More info at http://www.last.fm/api/show/auth.getToken */
  ScrobblerCallback cb = ^(NSDictionary *object) {
    authToken = object[@"token"];

    if (authToken == nil || [@"" isEqual:authToken]) {
      authToken = nil;
      [self error:@"Couldn't get an auth token from last.fm!"];
    } else {
      [self fetchSessionToken];
    }
  };

  [engine performMethod:@"auth.getToken"
           withCallback:[self errorChecker:cb handlesErrors:NO]
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

- (void) fetchSessionTokenAlready{
  isAlreadyAuth = @"1";
  [self fetchSessionToken];
}

- (void) fetchSessionToken {
  /* If we don't have an auth token, then fetch one and it will fetch a session
     token on succes */
  if (authToken == nil) {
    [self fetchAuthToken];
    return;
  }
  
  if (isAlreadyAuth == nil){
    [self needAuthorization];
    return;
  }
  NSLogd(@"Fetching session token for last.fm...");
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"api_key"] = _LASTFM_API_KEY_;
  dict[@"token"] = authToken;

  /* More info at http://www.last.fm/api/show/auth.getSession */
  ScrobblerCallback cb = ^(NSDictionary *object) {
    if (object[@"error"] != nil) {
      NSNumber *code = object[@"error"];

      if ([code intValue] == 14) {
        [self needAuthorization];
      } else {
        [self error:object[@"message"]];
      }
      sessionToken = nil;
      isAlreadyAuth = nil;
      [self fetchAuthToken];
      return;
    }

    NSDictionary *session = object[@"session"];
    sessionToken = session[@"key"];
    if (!KeychainSetItem(LASTFM_KEYCHAIN_ITEM, sessionToken)) {
      [self error:@"Couldn't save session token to keychain!"];
    }
  };

  [engine performMethod:@"auth.getSession"
           withCallback:[self errorChecker:cb handlesErrors:YES]
         withParameters:dict
           useSignature:YES
             httpMethod:@"GET"];
}

@end
