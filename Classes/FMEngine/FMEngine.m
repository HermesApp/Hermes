//
//  FMEngine.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import "FMEngine.h"
#import "FMCallback.h"
#import "FMEngineURLConnection.h"

@implementation FMEngine

static NSInteger sortAlpha(NSString *n1, NSString *n2, void *context) {
  return [n1 caseInsensitiveCompare:n2];
}

- (id)init {
  if ((self = [super init])) {
    connections = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (NSString *)generateAuthTokenFromUsername:(NSString *)username password:(NSString *)password {
  NSString *unencryptedToken = [NSString stringWithFormat:@"%@%@", username, [password md5sum]];
  return [unencryptedToken md5sum];
}

- (void)performMethod:(NSString *)method withTarget:(id)target withParameters:(NSDictionary *)params andAction:(SEL)callback useSignature:(BOOL)useSig httpMethod:(NSString *)httpMethod {
  NSString *dataSig;
  NSMutableURLRequest *request;
  NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] initWithDictionary:params];

  [tempDict setObject:method forKey:@"method"];
  if(useSig == TRUE) {
    dataSig = [self generateSignatureFromDictionary:tempDict];

    [tempDict setObject:dataSig forKey:@"api_sig"];
    NSLogd(@"scrobble with signature: %@", tempDict);
  }

  #ifdef _USE_JSON_
  if(![httpMethod isPOST]) {
    [tempDict setObject:@"json" forKey:@"format"];
  }

  #endif

  params = [NSDictionary dictionaryWithDictionary:tempDict];
  [tempDict release];

  if(![httpMethod isPOST]) {
    NSURL *dataURL = [self generateURLFromDictionary:params];
    request = [NSURLRequest requestWithURL:dataURL];
  } else {
    #ifdef _USE_JSON_
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_LASTFM_BASEURL_ stringByAppendingString:@"?format=json"]]];
    #else
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_LASTFM_BASEURL_]];
    #endif
    [request setHTTPMethod:httpMethod];
    [request setHTTPBody:[[self generatePOSTBodyFromDictionary:params] dataUsingEncoding:NSUTF8StringEncoding]];
  }

  FMEngineURLConnection *connection = [[FMEngineURLConnection alloc] initWithRequest:request];
  NSString *connectionId = [connection identifier];
  connection.callback = [FMCallback callbackWithTarget:target action:callback userInfo:nil object:connectionId];

  if(connection) {
    [connections setObject:connection forKey:connectionId];
    [connection release];
  }
}

- (NSData *)dataForMethod:(NSString *)method withParameters:(NSDictionary *)params useSignature:(BOOL)useSig httpMethod:(NSString *)httpMethod error:(NSError *)err {
  NSString *dataSig;
  NSMutableURLRequest *request;
  NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] initWithDictionary:params];

  [tempDict setObject:method forKey:@"method"];
  if(useSig == TRUE) {
    dataSig = [self generateSignatureFromDictionary:tempDict];

    [tempDict setObject:dataSig forKey:@"api_sig"];
  }

  #ifdef _USE_JSON_
  if(![httpMethod isPOST]) {
    [tempDict setObject:@"json" forKey:@"format"];
  }
  #endif

  [tempDict setObject:method forKey:@"method"];
  params = [NSDictionary dictionaryWithDictionary:tempDict];
  [tempDict release];

  if(![httpMethod isPOST]) {
    NSURL *dataURL = [self generateURLFromDictionary:params];
    request = [NSURLRequest requestWithURL:dataURL];
  } else {
    #ifdef _USE_JSON_
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_LASTFM_BASEURL_ stringByAppendingString:@"?format=json"]]];
    #else
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_LASTFM_BASEURL_]];
    #endif

    [request setHTTPMethod:httpMethod];
    [request setHTTPBody:[[self generatePOSTBodyFromDictionary:params] dataUsingEncoding:NSUTF8StringEncoding]];
  }

  NSData *returnData = [FMEngineURLConnection sendSynchronousRequest:request returningResponse:nil error:&err];
  return returnData;
}

- (NSString *)generatePOSTBodyFromDictionary:(NSDictionary *)dict {
  NSMutableString *rawBody = [[NSMutableString alloc] init];
  NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
  [aMutableArray sortUsingFunction:sortAlpha context:self];

  for(NSString *key in aMutableArray) {
    NSString *val = [NSString stringWithFormat:@"%@", [dict objectForKey:key]];
    [rawBody appendString:[NSString stringWithFormat:@"&%@=%@", key, [val urlEncoded]]];
  }

  NSString *body = [NSString stringWithString:rawBody];
  [rawBody release];
  [aMutableArray release];

  return body;
}

- (NSURL *)generateURLFromDictionary:(NSDictionary *)dict {
  NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
  NSMutableString *rawURL = [[NSMutableString alloc] init];
  [aMutableArray sortUsingFunction:sortAlpha context:self];
  [rawURL appendString:_LASTFM_BASEURL_];

  int i;

  for(i = 0; i < [aMutableArray count]; i++) {
    NSString *key = [aMutableArray objectAtIndex:i];
    NSString *val = [NSString stringWithFormat:@"%@", [dict objectForKey:key]];

    if(i == 0) {
      [rawURL appendString:[NSString stringWithFormat:@"?%@=%@", key, [val urlEncoded]]];
    } else {
      [rawURL appendString:[NSString stringWithFormat:@"&%@=%@", key, [val urlEncoded]]];
    }
  }

  NSString *encodedURL = [(NSString *)rawURL stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
  NSURL *url = [NSURL URLWithString:encodedURL];
  [rawURL release];
  [aMutableArray release];

  return url;
}

- (NSString *)generateSignatureFromDictionary:(NSDictionary *)dict {
  NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
  NSMutableString *rawSignature = [[NSMutableString alloc] init];
  [aMutableArray sortUsingFunction:sortAlpha context:self];

  for(NSString *key in aMutableArray) {
    [rawSignature appendString:[NSString stringWithFormat:@"%@%@", key, [dict objectForKey:key]]];
  }

  [rawSignature appendString:_LASTFM_SECRETK_];

  NSString *signature = [rawSignature md5sum];
  [rawSignature release];
  [aMutableArray release];

  return signature;
}

- (void)dealloc {

  [[connections allValues] makeObjectsPerformSelector:@selector(cancel)];
    [connections release];
  [super dealloc];
}

@end
