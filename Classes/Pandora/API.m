/**
 * @file Pandora/API.m
 * @brief Implementation of the API with Pandora
 *
 * Currently this is an implementation of the JSON protocol version 5, as
 * documented here: http://pan-do-ra-api.wikia.com/wiki/Json/5
 */

#include <string.h>
#import <SBJson/SBJson.h>

#import "FMEngine/NSString+FMEngine.h"
#import "Pandora/API.h"
#import "Pandora/Crypt.h"
#import "PreferencesController.h"
#import "URLConnection.h"

@implementation PandoraRequest

@synthesize callback, tls, authToken, userId, partnerId, response,
            request, method, encrypted;

- (id) init {
  authToken = partnerId = userId = @"";
  response = [[NSMutableData alloc] init];
  tls = encrypted = TRUE;
  return [super init];
}

@end

@implementation API

- (id) init {
  json_parser = [[SBJsonParser alloc] init];
  json_writer = [[SBJsonWriter alloc] init];
  return [super init];
}

/**
 * Gets the current UNIX time
 */
- (int64_t) time {
  return [[NSDate date] timeIntervalSince1970];
}

/**
 * @brief Send a request to Pandora
 *
 * All requests are performed asynchronously, so the callback listed in the
 * specified request will be invoked when the request completes.
 *
 * @param request the request to send. All information must be filled out
 *        beforehand which is related to this request
 * @return YES if the request went through, or NO otherwise.
 */
- (BOOL) sendRequest: (PandoraRequest*) request {
  NSString *url  = [NSString stringWithFormat:
      @"http%s://" PANDORA_API_HOST PANDORA_API_PATH
        @"?method=%@&partner_id=%@&auth_token=%@&user_id=%@",
      [request tls] ? "s" : "",
      [request method], [request partnerId],
      [[request authToken] urlEncoded], [request userId]];
  NSLogd(@"%@", url);

  /* Prepare the request */
  NSURL *nsurl = [NSURL URLWithString:url];
  NSMutableURLRequest *nsrequest = [NSMutableURLRequest requestWithURL:nsurl];
  [nsrequest setHTTPMethod: @"POST"];
  [nsrequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

  /* Create the body */
  NSData *data = [json_writer dataWithObject: [request request]];
  if ([request encrypted]) { data = PandoraEncrypt(data); }
  [nsrequest setHTTPBody: data];

  /* Create the connection with necessary callback for when done */
  URLConnection *c =
      [URLConnection connectionForRequest:nsrequest
                        completionHandler:^(NSData *d, NSError *e) {
    /* Parse the JSON if we don't have an error */
    NSDictionary *dict = nil;
    if (e == nil) {
      NSString *s = [[NSString alloc] initWithData:d
                                          encoding:NSUTF8StringEncoding];
      dict = [json_parser objectWithString:s error:&e];
    }
    /* If we still don't have an error, look at the JSON for an error */
    NSString *err = e == nil ? nil : [e localizedDescription];
    if (dict != nil && err == nil) {
      NSString *stat = [dict objectForKey:@"stat"];
      if ([stat isEqualToString:@"fail"]) {
        err = [dict objectForKey:@"message"];
      }
    }

    /* If we don't have an error, then all we need to do is invoked the
       specified callback, otherwise build the error dictionary. */
    if (err == nil) {
      assert(dict != nil);
      [request callback](dict);
      return;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];

    [info setValue:request forKey:@"request"];
    [info setValue:err     forKey:@"error"];
    if (dict != nil) {
      [info setValue:[dict objectForKey:@"code"] forKey:@"code"];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hermes.pandora-error"
                                                        object:self
                                                      userInfo:info];
  }];
  [c start];
  return TRUE;
}

@end
