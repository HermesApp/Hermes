//
//  API.h
//  Hermes
//
//  Created by Alex Crichton on 3/15/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#include <libxml/parser.h>

@interface API : NSObject {
  NSString *listenerID;
}

@property (retain) NSString* listenerID;

- (int) time;
- (NSArray*) xpath: (xmlDocPtr) doc : (char*) xpath;
- (NSString*) xpathText: (xmlDocPtr)doc : (char*) xpath;
- (xmlDocPtr) sendRequest: (NSString*)method : (NSString*)data;

@end
