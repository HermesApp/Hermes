#define PANDORA_API_HOST @"tuner.pandora.com"
#define PANDORA_API_PATH @"/services/json/"
#define PANDORA_API_VERSION @"5"

typedef void(^PandoraCallback)(NSDictionary*);

@class SBJsonParser;
@class SBJsonWriter;

@interface PandoraRequest : NSObject

/* URL parameters */
@property NSString *method;
@property NSString *authToken;
@property NSString *partnerId;
@property NSString *userId;

/* JSON data */
@property NSMutableDictionary *request;
@property NSMutableData *response;

/* Internal metadata */
@property (copy) PandoraCallback callback;
@property BOOL tls;
@property BOOL encrypted;

@end

@interface API : NSObject {
  int64_t syncOffset;

  /* JSON parsing */
  SBJsonParser *json_parser;
  SBJsonWriter *json_writer;
}

- (int64_t) time;
- (BOOL) sendRequest: (PandoraRequest*) request;

@end
