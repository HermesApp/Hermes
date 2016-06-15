/**
 * @file Scrobbler.m
 * @brief Implementation of talking with Last.fm
 *
 * Handles the serialization of requests to Last.fm and handles all errors
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
 * Also begins fetching of session keys for the Last.fm API
 */
- (id) init {
  if (!(self = [super init])) { return self; }

  engine = [[FMEngine alloc] init];
  sessionToken = KeychainGetPassword(LASTFM_KEYCHAIN_ITEM);
  if ([@"" isEqualToString:sessionToken]) {
    sessionToken = nil;
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
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

typedef void(^ScrobblerCallback)(NSDictionary*);

/**
 * @brief Generates a callback for the FMEngine to handle errors
 *
 * @param callback the callback to be invoked with the parsed JSON object if
 *        the JSON was received without error and parsed without error
 * @param handles if YES, then the callback will always be invoked with valid
 *        JSON, otherwise if the json contains a Last.fm error, the error will
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

    /* If this is a Last.fm error, however, then this is a serious issue which
     * may need to be addressed manually, so do display a dialog here */
    if (error != nil) {
      [self error:[error localizedDescription]];
    } else if (!handles && object[@"error"] != nil) {
      NSLogd(@"Last.fm error: %@", object);
      NSInteger errorCode = [object[@"error"] integerValue];
      
      switch (errorCode) {
        case 9: /* Invalid session key - Please re-authenticate */
          sessionToken = nil;
          [self fetchRequestToken];
          break;
        case 8: /* Operation failed - Most likely the backend service failed. Please try again. */
        case 16: /* The service is temporarily unavailable, please try again */
          break;
        default:
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
  Song *song = [not object];
  if (song) {
    [self setPreference:song loved:([song.nrating integerValue] == 1)];
  }
}

/**
 * @brief Internal helper method to display an error message
 */
- (void) error: (NSString*) message {
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Last.fm returned an error";
  alert.informativeText = message;
  [alert addButtonWithTitle:@"OK"];
  [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:nil];
}

/**
 * @brief Scrobbles a song to Last.fm
 *
 * This can be used for any ScrobbleState, but should only be sent at the
 * appropriate time as per Last.fm's guidelines.
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
    /* just lose this scrobble; it's not mission critical anyway */
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
 * @brief Tell Last.fm that a track is 'loved' or 'unloved'
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
 * If canceled, then Last.fm is turned off. Otherwise, when confirmed, the user
 * is redirected to a page to approve Hermes. We give them a bit to do this
 * and then we try to get a session token (which despite its name is valid
 * indefinitely).
 */
- (void) requestAuthorization {
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Allow Hermes to scrobble on Last.fm";
  alert.informativeText = @"Click “Authorize” to give Hermes permission to access your Last.fm account.\n\nHermes will not try to use Last.fm for at least 30 seconds to give you time to grant permission.\n\nClick “Don’t Scrobbleʺ to stop Hermes from trying to use Last.fm.";
  [alert addButtonWithTitle:@"Authorize"];
  [alert addButtonWithTitle:@"Don’t Scrobble"];
  [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse returnCode) {
    if (returnCode != NSAlertFirstButtonReturn) {
      PREF_KEY_SET_BOOL(PLEASE_SCROBBLE, NO);
      inAuthorization = NO;
      return;
    }
    
    NSString *authURL = [NSString stringWithFormat:
                         @"http://www.last.fm/api/auth/?api_key=%@&token=%@",
                         _LASTFM_API_KEY_, requestToken];
    NSURL *url = [NSURL URLWithString:authURL];
    
    [[NSWorkspace sharedWorkspace] openURL:url];
    
    /* Give the user some time to authorize the request token. Then try to get a session token again */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      inAuthorization = NO;
      [self fetchSessionToken];
    });
  }];
}

/**
 * @brief Fetch an unauthorized request token
 *
 */
- (void) fetchRequestToken {
  if (inAuthorization)
    return;

  inAuthorization = YES;

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"api_key"] = _LASTFM_API_KEY_;

  /* More info at http://www.last.fm/api/show/auth.getToken */
  ScrobblerCallback cb = ^(NSDictionary *object) {
    requestToken = object[@"token"];

    if (requestToken == nil || [@"" isEqual:requestToken]) {
      requestToken = nil;
      [self error:@"Couldn't get an authentication request token from last.fm!"];
      inAuthorization = NO;
    } else {
      [self requestAuthorization];
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
 * If we try to do this with an unauthorized request token, this will invalidate it, so we need to start over.
 */
- (void) fetchSessionToken {
  if (inAuthorization)
    return;
  if (requestToken == nil) {
    [self fetchRequestToken];
    return;
  }

  NSLogd(@"Fetching session token for Last.fm...");
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"api_key"] = _LASTFM_API_KEY_;
  dict[@"token"] = requestToken;
  requestToken = nil; // can be used only once

  /* More info at http://www.last.fm/api/show/auth.getSession */
  ScrobblerCallback cb = ^(NSDictionary *object) {
    if (object[@"error"] != nil) {
      NSLogd(@"Last.fm session token error: %@", object);

      if ([object[@"error"] integerValue] == 14) { /* Unauthorized Token - This token has not been authorized */
        [self fetchRequestToken];
      } else {
        [self error:object[@"message"]];
      }
      sessionToken = nil;
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
