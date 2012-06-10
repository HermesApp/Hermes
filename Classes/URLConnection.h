typedef void(^URLConnectionCallback)(NSData*, NSError*);

@interface URLConnection : NSObject {
  CFReadStreamRef stream;
  URLConnectionCallback cb;
  NSMutableData *bytes;
}

+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(URLConnectionCallback) cb;
+ (void) setHermesProxy: (CFReadStreamRef) stream;

- (void) start;
- (void) setHermesProxy;

@end
