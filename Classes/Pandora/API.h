//
//  API.h
//  Hermes
//
//  Created by Alex Crichton on 3/15/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#include <libxml/parser.h>

#pragma once

#define PANDORA_API_HOST @"www.pandora.com"
#define PANDORA_API_PATH @"/radio/xmlrpc/"
#define PANDORA_API_VERSION @"v31"

@interface ConnectionData : NSObject {
  SEL callback;
  NSMutableData *data;
  id info;
}

@property (readwrite) SEL callback;
@property (retain) NSMutableData *data;
@property (retain) id info;

@end

@interface API : NSObject {
  NSString *listenerID;

  NSMutableDictionary *activeRequests;
}

@property (retain) NSString* listenerID;

- (int) time;
- (NSArray*) xpath: (xmlDocPtr) doc : (char*) xpath;
- (NSString*) xpathText: (xmlDocPtr)doc : (char*) xpath;
- (BOOL) sendRequest: (NSString*)method : (NSString*)data : (SEL)callback;
- (BOOL) sendRequest: (NSString*)method : (NSString*)data : (SEL)callback : (id)info;

@end
