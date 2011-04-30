//
//  Scrobbler.m
//  Hermes
//
//  Created by Alex Crichton on 4/27/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Keychain.h"
#import "Scrobbler.h"
#import "Station.h"
#import <JSON/JSON.h>

#define LASTFM_KEYCHAIN_ITEM @"hermes-lastfm-sk"

Scrobbler *subscriber = nil;

@implementation Scrobbler

@synthesize engine, authToken, sessionToken;

+ (void) subscribe {
  if (subscriber != nil) {
    return;
  }

  subscriber = [[Scrobbler alloc] init];
}

+ (void) unsubscribe {
  if (subscriber == nil) {
    return;
  }

  [subscriber release];
  subscriber = nil;
}

- (void) error: (NSString*) message {
  NSString *header = @"last.fm error: ";
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  message = [header stringByAppendingString:message];
  [alert setMessageText:message];
  [alert addButtonWithTitle:@"OK"];
  [alert beginSheetModalForWindow:[[NSApp delegate] window]
                    modalDelegate:self
                   didEndSelector:nil
                      contextInfo:nil];
}

/**
 * Display a dialog saying that we need authorization from the user. If
 * canceled, then last.fm is turned off. Otherwise, when confirmed, the user
 * is redirected to a page to approve Hermes. We give them a bit to do this
 * and then we automatically retry to get the authorization token
 */
- (void) needAuthorization {
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert setMessageText:@"Hermes needs authorization to scrobble on last.fm"];
  [alert addButtonWithTitle:@"OK"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert beginSheetModalForWindow:[[NSApp delegate] window]
                    modalDelegate:self
                   didEndSelector:@selector(openAuthorization:returnCode:contextInfo:)
                      contextInfo:nil];
}

/**
 * Callback for when the user closes the 'need authorization' dialog
 */
- (void) openAuthorization:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
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

- (id) init {
  if (self = [super init]) {
    [self setEngine:[[FMEngine alloc] init]];

    /* Try to get the saved session token, otherwise get a new one */
    NSString *str = [Keychain getKeychainPassword:LASTFM_KEYCHAIN_ITEM];
    if (str == nil || [str isEqual:@""]) {
      [self fetchAuthToken];
    } else {
      [self setSessionToken:str];
    }

    /* Subscribe to notifications of songs playing */
    [[NSNotificationCenter defaultCenter]
      addObserver:self
      selector:@selector(songPlayed:)
      name:@"song.playing"
      object:nil];
  }

  return self;
}

- (void) dealloc {
  if (timer != nil && [timer isValid]) {
    [timer invalidate];
  }
  [engine release];
  [authToken release];
  [sessionToken release];

  [[NSNotificationCenter defaultCenter]
    removeObserver:self
    name:@"song.playing"
    object:nil];

  [super dealloc];
}

/**
 * Callback for when a song plays. This triggers the actual scrobbling
 */
- (void) songPlayed: (NSNotification *)aNotification {
  /* If we don't have a sesion token yet, just ignore this for now */
  if (sessionToken == nil || [@"" isEqual:sessionToken]) {
    return;
  }

  Song *s = [[aNotification object] playing];
  if (s == nil) {
    return;
  }

  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

  [dictionary setObject:sessionToken forKey:@"sk"];
  [dictionary setObject:_LASTFM_API_KEY_ forKey:@"api_key"];
  [dictionary setObject:[s title] forKey:@"track"];
  [dictionary setObject:[s artist] forKey:@"artist"];
  [dictionary setObject:[s album] forKey:@"album"];
  [dictionary setObject:[s musicId] forKey:@"mbid"];

  NSNumber *time = [NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]];
  [dictionary setObject:time forKey:@"timestamp"];

  [engine performMethod:@"track.scrobble"
             withTarget:self
         withParameters:dictionary
              andAction:@selector(finishedScrobbling::)
           useSignature:YES
             httpMethod:@"POST"];
}

/**
 * Callback for when the scrobbling request completes
 */
- (void) finishedScrobbling: (id) _ignored : (NSData*) data {
  SBJsonParser *parser = [[SBJsonParser alloc] init];

  NSDictionary *object = [parser objectWithData:data];

  if ([object objectForKey:@"error"] != nil) {
    [self error:[object objectForKey:@"message"]];
  }

  [parser release];
}

/**
 * Fetch an authorization token. This is then used to get a session token
 */
- (void) fetchAuthToken {
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
  [dict setObject:_LASTFM_API_KEY_ forKey:@"api_key"];

  [engine performMethod:@"auth.getToken"
             withTarget:self
         withParameters:dict
              andAction:@selector(gotAuthToken::)
           useSignature:YES
             httpMethod:@"GET"];
}

/**
 * Callback for when we finished getting an authorization token
 */
- (void) gotAuthToken: (id) _ignored : (NSData*) data {
  SBJsonParser *parser = [[SBJsonParser alloc] init];

  NSDictionary *object = [parser objectWithData:data];

  [self setAuthToken:[object objectForKey:@"token"]];
  [parser release];

  if (authToken == nil || [@"" isEqual:authToken]) {
    [self setAuthToken:nil];
    [self error:@"Couldn't get an auth token from last.fm!"];
  } else {
    [self fetchSessionToken];
  }
}

/**
 * Fetch a session token for a logged in user. This will generate an error if
 * they haven't approved our authentication token, but then we ask them to
 * approve it and we retry with the same authorization token.
 */
- (void) fetchSessionToken {
  NSLog(@"fetchinG");
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
  [dict setObject:_LASTFM_API_KEY_ forKey:@"api_key"];
  [dict setObject:authToken forKey:@"token"];

  [engine performMethod:@"auth.getSession"
             withTarget:self
         withParameters:dict
              andAction:@selector(gotSessionToken::)
           useSignature:YES
             httpMethod:@"GET"];
}

/**
 * Callback for when the getSession request completes
 */
- (void) gotSessionToken: (id) _ignored : (NSData*) data {
  SBJsonParser *parser = [[SBJsonParser alloc] init];
  NSDictionary *object = [parser objectWithData:data];

  if ([object objectForKey:@"error"] != nil) {
    NSNumber *code = [object objectForKey:@"error"];

    if ([code intValue] == 14) {
      [self needAuthorization];
    } else {
      [self error:[object objectForKey:@"message"]];
    }
  }

  NSDictionary *session = [object objectForKey:@"session"];
  [self setSessionToken:[session objectForKey:@"key"]];
  [Keychain setKeychainItem:LASTFM_KEYCHAIN_ITEM : sessionToken];
}

@end
