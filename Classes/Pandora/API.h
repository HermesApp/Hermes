#include <libxml/parser.h>

#pragma once

#define PANDORA_API_HOST @"www.pandora.com"
#define PANDORA_API_PATH @"/radio/xmlrpc/"
#define PANDORA_API_VERSION @"v31"

@interface PandoraRequest : NSObject {
  @private
  SEL callback;
  NSObject *info;
  NSString *requestData;
  NSString *requestMethod;
  NSMutableData *responseData;
}

@property (readonly) NSString *requestData;
@property (readonly) NSString *requestMethod;
@property (readonly) NSMutableData *responseData;
@property (readonly) NSObject *info;
@property (readonly) SEL callback;

+ (PandoraRequest*) requestWithMethod: (NSString*)requestMethod
                                 data: (NSString*) data
                             callback: (SEL) callback
                                 info: (NSObject*) info;
@end

@interface API : NSObject {
  NSString *listenerID;

  NSMutableDictionary *activeRequests;
}

@property (retain) NSString* listenerID;

- (int) time;
- (NSArray*) xpath: (xmlDocPtr) doc : (char*) xpath;
- (NSString*) xpathText: (xmlDocPtr)doc : (char*) xpath;
- (BOOL) sendRequest: (PandoraRequest*) request;

@end
