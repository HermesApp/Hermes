//
//  Scrobbler.h
//  Hermes
//
//  Created by Alex Crichton on 4/27/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "FMEngine.h"

#define TOKEN_NOT_AUTHORIZED 14

@interface Scrobbler : NSObject {
  FMEngine *engine;
  NSString *authToken;
  NSString *sessionToken;
  NSTimer *timer;
}

+ (void) subscribe;
+ (void) unsubscribe;

@property (retain) FMEngine *engine;
@property (retain) NSString *authToken;
@property (retain) NSString *sessionToken;

- (void) fetchAuthToken;
- (void) fetchSessionToken;

@end
