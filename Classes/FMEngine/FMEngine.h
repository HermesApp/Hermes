//
//  FMEngine.h
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+FMEngine.h"

#define _LASTFM_API_KEY_ @"2116c8771c6a03bb89c24a0935bea3a4"
#define _LASTFM_SECRETK_ @"7f363485e3dedbefec78c9087402a75d"
#define _LASTFM_BASEURL_ @"http://ws.audioscrobbler.com/2.0/"

// Comment the next line to use XML
#define _USE_JSON_ 1

#define POST_TYPE  @"POST"
#define GET_TYPE   @"GET"

typedef void(^FMCallback)(NSData*, NSError*);

@class FMEngine;

@interface FMEngine : NSObject {
  NSMutableData *receivedData;
}

- (NSString *)generateAuthTokenFromUsername:(NSString *)username password:(NSString *)password;
- (NSString *)generateSignatureFromDictionary:(NSDictionary *)dict;
- (NSString *)generatePOSTBodyFromDictionary:(NSDictionary *)dict;
- (NSURL *)generateURLFromDictionary:(NSDictionary *)dict;

- (void)performMethod:(NSString *)method withCallback:(FMCallback)cb withParameters:(NSDictionary *)params useSignature:(BOOL)useSig httpMethod:(NSString *)httpMethod;

@end
