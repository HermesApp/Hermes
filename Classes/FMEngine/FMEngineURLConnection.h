//
//  FMEngineURLConnection.h
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/28/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMEngine.h"
#import "NSString+FMEngine.h"

@interface FMEngineURLConnection : NSURLConnection {
  @public
  FMCallback callback;

  @private
  NSString *_id;
  NSMutableData *_receivedData;
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate;
- (id)initWithRequest:(NSURLRequest *)request;
- (void)appendData:(NSData *)moreData;
- (NSData *)data;
- (NSString *)identifier;

@end
