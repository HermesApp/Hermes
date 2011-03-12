//
//  Station.h
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

@interface Station : NSObject {
  NSString *name;
  NSString *station_id;
}

@property (retain) NSString* name;
@property (retain) NSString* station_id;

@end
