//
//  FMEngineURLConnection.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/28/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import "FMEngineURLConnection.h"

@implementation FMEngineURLConnection

@synthesize callback;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
  if (self = [super initWithRequest:request delegate:delegate]) {
    _receivedData = [[NSMutableData alloc] initWithCapacity:0];
    _id = [[NSString stringWithNewUUID] retain];
  }
  return self;
}

- (id)initWithRequest:(NSURLRequest *)request {
  if (self = [super initWithRequest:request delegate:self]) {
    _receivedData = [[NSMutableData alloc] initWithCapacity:0];
    _id = [[NSString stringWithNewUUID] retain];
  }
  return self;
}

- (void)connection:(FMEngineURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [_receivedData setLength:0];
}

- (void)connection:(FMEngineURLConnection *)connection didReceiveData:(NSData *)data {
    [_receivedData appendData:data];
}

- (void)connection:(FMEngineURLConnection *)connection didFailWithError:(NSError *)error {
  // TODO: Error Handling
  [callback setUserInfo:error];
  [callback fire];

    [connection release];
    [_receivedData release];
}

- (void)connectionDidFinishLoading:(FMEngineURLConnection *)connection {
  [callback setUserInfo:_receivedData];
  [callback fire];

    [connection release];
    [_receivedData release];
}

- (void)appendData:(NSData *)moreData {
  [_receivedData appendData:moreData];
}

- (NSData *)data {
  return _receivedData;
}

- (NSString *)identifier {
  return _id;
}

- (void)dealloc {
  [callback release];

  [super dealloc];
}

@end
