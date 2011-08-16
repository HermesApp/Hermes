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

@property (retain) NSString *requestData;
@property (retain) NSString *requestMethod;
@property (retain) NSMutableData *responseData;
@property (retain) NSObject *info;
@property (readwrite) SEL callback;

+ (PandoraRequest*) requestWithMethod: (NSString*) requestMethod
                                 data: (NSString*) data
                             callback: (SEL) callback
                                 info: (NSObject*) info;
- (void) resetResponse;
- (void) replaceAuthToken:(NSString*) token with:(NSString*) replacement;
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
