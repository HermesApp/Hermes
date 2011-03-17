//
//  ImageLoader.h
//  Hermes
//
//  Created by Alex Crichton on 3/16/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ImageLoader : NSObject {
  NSURLConnection *prev;
  NSMutableData *data;
  NSString *loadedURL;
}

@property (retain) NSMutableData *data;
@property (retain) NSString *loadedURL;

- (void) loadImageURL: (NSString*) url;

@end
