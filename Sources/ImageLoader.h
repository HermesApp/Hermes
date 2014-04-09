@class URLConnection;

typedef void(^ImageCallback)(NSData*);

@interface ImageLoader : NSObject {
  NSMutableArray *queue;
  NSMutableArray *cbqueue;
  URLConnection *cur;
  NSString *curURL;
}

+ (ImageLoader*) loader;

- (void) loadImageURL:(NSString*)url callback:(ImageCallback)cb;
- (void) cancel: (NSString*)url;

@end
