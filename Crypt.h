//
//  Crypt.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

@interface Crypt : NSObject {

}

+ (NSString*) encrypt: (NSString*) string;
+ (NSString*) decrypt: (NSString*) string;

@end
