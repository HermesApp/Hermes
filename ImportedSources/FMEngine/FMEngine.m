//
//  FMEngine.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import "FMEngine.h"
#import "URLConnection.h"

@implementation FMEngine

static NSInteger sortAlpha(NSString *n1, NSString *n2, void *context) {
  return [n1 caseInsensitiveCompare:n2];
}

- (NSString *)generateAuthTokenFromUsername:(NSString *)username password:(NSString *)password {
  NSString *unencryptedToken = [NSString stringWithFormat:@"%@%@", username, [password md5sum]];
  return [unencryptedToken md5sum];
}

- (void) performMethod:(NSString *)method
          withCallback:(FMCallback)callback
        withParameters:(NSDictionary *)params
          useSignature:(BOOL)useSig
            httpMethod:(NSString *)httpMethod {
  NSString *dataSig;
  NSMutableURLRequest *request;
  NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] initWithDictionary:params];

  tempDict[@"method"] = method;
  if(useSig == TRUE) {
    dataSig = [self generateSignatureFromDictionary:tempDict];

    tempDict[@"api_sig"] = dataSig;
    NSLogd(@"%@", tempDict);
  }

  #ifdef _USE_JSON_
  if(![httpMethod isEqualToString:@"POST"]) {
    tempDict[@"format"] = @"json";
  }
  #endif

  params = [NSDictionary dictionaryWithDictionary:tempDict];

  if(![httpMethod isEqualToString:@"POST"]) {
    NSURL *dataURL = [self generateURLFromDictionary:params];
    request = [NSMutableURLRequest requestWithURL:dataURL];
  } else {
    #ifdef _USE_JSON_
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_LASTFM_BASEURL_ @"?format=json"]];
    #else
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_LASTFM_BASEURL_]];
    #endif
    [request setHTTPMethod:httpMethod];
    [request setHTTPBody:[[self generatePOSTBodyFromDictionary:params] dataUsingEncoding:NSUTF8StringEncoding]];
    [request      addValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
  }

  URLConnection *connection = [URLConnection connectionForRequest:request
                                                completionHandler:callback];
  [connection start];
}

- (NSString *)generatePOSTBodyFromDictionary:(NSDictionary *)dict {
  NSMutableString *rawBody = [[NSMutableString alloc] init];
  NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
  [aMutableArray sortUsingFunction:sortAlpha context:NULL];

  for(NSString *key in aMutableArray) {
    NSString *val = [NSString stringWithFormat:@"%@", dict[key]];
    [rawBody appendString:[NSString stringWithFormat:@"&%@=%@", key, [val urlEncoded]]];
  }

  NSString *body = [NSString stringWithString:rawBody];

  return body;
}

- (NSURL *)generateURLFromDictionary:(NSDictionary *)dict {
  NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
  NSMutableString *rawURL = [NSMutableString stringWithString:_LASTFM_BASEURL_];
  [aMutableArray sortUsingFunction:sortAlpha context:NULL];

  for(unsigned int i = 0; i < [aMutableArray count]; i++) {
    NSString *key = aMutableArray[i];
    NSString *val = [NSString stringWithFormat:@"%@", dict[key]];

    if(i == 0) {
      [rawURL appendString:[NSString stringWithFormat:@"?%@=%@", key, [val urlEncoded]]];
    } else {
      [rawURL appendString:[NSString stringWithFormat:@"&%@=%@", key, [val urlEncoded]]];
    }
  }

  NSString *encodedURL = [rawURL stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
  NSURL *url = [NSURL URLWithString:encodedURL];

  return url;
}

- (NSString *)generateSignatureFromDictionary:(NSDictionary *)dict {
  NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
  NSMutableString *rawSignature = [[NSMutableString alloc] init];
  [aMutableArray sortUsingFunction:sortAlpha context:NULL];

  for(NSString *key in aMutableArray) {
    [rawSignature appendString:[NSString stringWithFormat:@"%@%@", key, dict[key]]];
  }

  [rawSignature appendString:_LASTFM_SECRETK_];

  NSString *signature = [rawSignature md5sum];
  return signature;
}

@end
