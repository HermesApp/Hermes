#ifndef _API_H
#define _API_H

#define PANDORA_API_HOST @"tuner.pandora.com"
#define PANDORA_API_PATH @"/services/json/"
#define PANDORA_API_VERSION @"5"

typedef void(^PandoraCallback)(NSDictionary*);

@class SBJsonParser;
@class SBJsonWriter;

@interface PandoraRequest : NSObject {
  /* Internal metadata */
  PandoraCallback callback;
  BOOL tls;
  BOOL encrypted;

  /* URL parameters */
  NSString *method;
  NSString *authToken;
  NSString *partnerId;
  NSString *userId;

  /* JSON data */
  NSMutableDictionary *request;
  NSMutableData *response;
}

@property (retain, readwrite) NSString *method;
@property (retain, readwrite) NSString *authToken;
@property (retain, readwrite) NSString *partnerId;
@property (retain, readwrite) NSString *userId;
@property (retain, readwrite) NSMutableDictionary *request;
@property (retain, readwrite) NSMutableData *response;
@property (copy) PandoraCallback callback;
@property (readwrite) BOOL tls;
@property (readwrite) BOOL encrypted;

@end

@interface API : NSObject {
  NSMutableDictionary *activeRequests;
  int64_t syncOffset;

  /* JSON parsing */
  SBJsonParser *json_parser;
  SBJsonWriter *json_writer;
}

- (int64_t) time;
- (BOOL) sendRequest: (PandoraRequest*) request;

@end

#endif /* _API_H */
