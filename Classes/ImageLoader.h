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
}

@property (retain) NSMutableData *data;

- (void) loadImageURL: (NSString*) url;

@end
