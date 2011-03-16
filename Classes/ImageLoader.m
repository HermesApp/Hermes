//
//  ImageLoader.m
//  Hermes
//
//  Created by Alex Crichton on 3/16/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "ImageLoader.h"

@implementation ImageLoader

@synthesize data;

- (void) notify {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"image-loaded" object:self];
}

- (void) loadImageURL: (NSString*) url {
  if (prev != nil) {
    [prev cancel];
    [prev release];
  }

  [self setData:[NSMutableData dataWithCapacity:100]];

  NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  prev = [[NSURLConnection alloc] initWithRequest:req delegate:self];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)d {
  [data appendData:d];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveResponse:(NSHTTPURLResponse *)response {

  if ([response statusCode] < 200 || [response statusCode] >= 300) {
    [connection cancel];
    [self notify];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [self notify];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  [self notify];
}

@end
