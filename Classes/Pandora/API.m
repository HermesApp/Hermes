/**
 * @file Pandora/API.m
 * @brief Implementation of the API with Pandora
 *
 * Currently this is an implementation of the JSON protocol version 5, as
 * documented here: http://pan-do-ra-api.wikia.com/wiki/Json/5
 */

#include <string.h>
#import <Foundation/NSJSONSerialization.h>

#import "FMEngine/NSString+FMEngine.h"
#import "Pandora/API.h"
#import "Pandora/Crypt.h"
#import "PreferencesController.h"

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
  activeRequests = [[NSMutableDictionary alloc] init];
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
  NSError *error;
  NSData *data = [NSJSONSerialization dataWithJSONObject:[request request]
                                                 options:0
                                                   error:&error];
  assert(error == nil);
  if ([request encrypted]) { data = PandoraEncrypt(data); }
  [nsrequest setHTTPBody: data];

  /* Fetch the response asynchronously */
  NSURLConnection *conn = [[NSURLConnection alloc]
    initWithRequest:nsrequest delegate:self];

  [activeRequests setObject:request
    forKey:[NSNumber numberWithInteger: [conn hash]]];

  return YES;
}

/**
 * @brief Helper for getting the request associated with a connection
 *
 * @param connection the connection to get a request for
 * @return the associated PandoraRequest object
 */
- (PandoraRequest*) dataForConnection: (NSURLConnection*)connection {
  return [activeRequests objectForKey:
      [NSNumber numberWithInteger:[connection hash]]];
}

/**
 * @brief Cleans up all resources associated with a connection
 *
 * @param connection the connection to clean up
 * @param res the response from Pandora (parsed JSON), or nil if there wasn't
 *        one
 * @param fault the fault message if there is one already available, or nil
 */
- (void)cleanupConnection:(NSURLConnection *)connection : (NSDictionary*)res
                         :(NSString*) fault {
  PandoraRequest *request = [self dataForConnection:connection];

  /* Look for a fault message in the JSON if there is one */
  if (res != nil && fault == nil) {
    NSString *stat = [res objectForKey: @"stat"];
    if ([stat isEqualToString: @"fail"]) {
      fault = [res objectForKey: @"message"];
    }
  }

  if (res == nil || fault != nil) {
    NSLogd(@"%@ %@", res, fault);
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (fault == nil) {
      fault = @"Connection error";
    }
    NSArray *parts = [fault componentsSeparatedByString:@"|"];
    if ([parts count] >= 3) {
      fault = [parts objectAtIndex:2];
    }
    NSLogd(@"Fault: %@", fault);

    [info setValue:request forKey:@"request"];
    [info setValue:fault   forKey:@"error"];
    if (res != nil) {
      [info setValue:[res objectForKey:@"code"] forKey:@"code"];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hermes.pandora-error"
                                                        object:self
                                                      userInfo:info];
  } else {
    /* Only invoke the callback if there's no faults */
    [request callback](res);
  }

  /* Always free these up */
  [activeRequests removeObjectForKey:[NSNumber numberWithInteger: [connection hash]]];
}

/* Implementation of the NSURLDelegate protocols */

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  PandoraRequest *request = [self dataForConnection:connection];
  [[request response] appendData:data];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveResponse:(NSHTTPURLResponse *)response {
  if ([response statusCode] < 200 || [response statusCode] >= 300) {
    NSLogd(@"%ld", [response statusCode]);
    [connection cancel];
    [self cleanupConnection:connection : NULL : @"Didn't receive 2xx response"];
  }
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
  [self cleanupConnection:connection : NULL : [error localizedDescription]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  PandoraRequest *request = [self dataForConnection:connection];
#ifdef DEBUG
  NSString *str = [[NSString alloc] initWithData:[request response]
                                        encoding:NSASCIIStringEncoding];
  NSLog(@"%@", str);
#endif

  NSError *error;
  NSDictionary *dict =
    [NSJSONSerialization JSONObjectWithData:[request response]
                                    options:NSJSONReadingMutableContainers
                                      error:&error];
  NSString *err = nil;
  if (error != nil) {
    err = [error localizedDescription];
  }
  [self cleanupConnection:connection : dict : err];
}

@end
