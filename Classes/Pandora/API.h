#include <libxml/parser.h>

#pragma once

#define PANDORA_API_HOST @"www.pandora.com"
#define PANDORA_API_PATH @"/radio/xmlrpc/"
#define PANDORA_API_VERSION @"v33"

typedef void(^PandoraCallback)(xmlDocPtr);

@interface PandoraRequest : NSObject {
  @private
  NSString *requestData;
  NSString *requestMethod;
  NSMutableData *responseData;
  PandoraCallback callback;
}

@property (retain) NSString *requestData;
@property (retain) NSString *requestMethod;
@property (retain) NSMutableData *responseData;
@property (retain) PandoraCallback callback;
@property (retain) NSObject *info;

+ (PandoraRequest*) requestWithMethod: (NSString*) requestMethod
                                 data: (NSString*) data
                             callback: (PandoraCallback) callback;
- (void) resetResponse;
- (void) replaceAuthToken:(NSString*) token with:(NSString*) replacement;
@end

BOOL xpathNodes(xmlDocPtr doc, char* xpath, void (^callback)(xmlNodePtr));
NSString *xpathRelative(xmlDocPtr doc, char* xpath, xmlNodePtr node);

@interface API : NSObject {
  NSString *listenerID;

  NSMutableDictionary *activeRequests;
  int64_t syncOffset;
}

@property (retain) NSString* listenerID;

- (int64_t) time;
- (BOOL) sendRequest: (PandoraRequest*) request;

@end
