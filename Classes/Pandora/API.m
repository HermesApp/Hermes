/**
 * @file Pandora/API.m
 * @brief Implementation of the API with Pandora
 *
 * Currently this is an implementation of the JSON protocol version 5, as
 * documented here: http://pan-do-ra-api.wikia.com/wiki/Json/5
 */

#include <string.h>

#import "API.h"
#import "Crypt.h"
#import "SBJson.h"
#import "NSString+FMEngine.h"

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
 * Sends a request to the server and parses the response as XML
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

  /* Fetch the response asynchronously */
  NSURLConnection *conn = [[NSURLConnection alloc]
    initWithRequest:nsrequest delegate:self];

  [activeRequests setObject:request
    forKey:[NSNumber numberWithInteger: [conn hash]]];

  return YES;
}

/* Helper method for getting the PandoraRequest for a connection */
- (PandoraRequest*) dataForConnection: (NSURLConnection*)connection {
  return [activeRequests objectForKey:
      [NSNumber numberWithInteger:[connection hash]]];
}

/* Cleans up the specified connection with the parsed XML. This method will
   check the document for errors (if the document exists. The error event
   will be published through the default NSNotificationCenter, or the
   callback for the connection will be invoked */
- (void)cleanupConnection:(NSURLConnection *)connection : (NSDictionary*)res : (NSString*) fault {
  PandoraRequest *request = [self dataForConnection:connection];

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

/* Collect the data received */
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

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [self cleanupConnection:connection : NULL : [error localizedDescription]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  PandoraRequest *request = [self dataForConnection:connection];
#ifdef DEBUG
  NSString *str = [[NSString alloc] initWithData:[request response]
                                        encoding:NSASCIIStringEncoding];
  NSLog(@"%@", str);
#endif

  NSDictionary *dict = [json_parser objectWithData: [request response]];
  [self cleanupConnection:connection : dict : nil];
}

@end
