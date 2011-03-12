//
//  Song.h
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Song : NSObject {
  NSString *artist;
  NSString *title;
  NSString *art;
  NSString *url;
}

@property (retain) NSString* artist;
@property (retain) NSString* title;
@property (retain) NSString* art;
@property (retain) NSString* url;

+ (NSString*) decryptURL: (NSString*) url;

@end
