//
//  FMEngine.h
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+FMEngine.h"

#define _LASTFM_API_KEY_ @"3676c5404da15ace5076aa3101e93a3f"
#define _LASTFM_SECRETK_ @"ba5987f69cdb74535278f4d9e64c0807"
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
