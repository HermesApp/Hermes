@class URLConnection;

@interface ImageLoader : NSObject {
  URLConnection *prev;
  NSData *data;
  NSString *loadedURL;
}

@property (retain) NSData *data;
@property (retain) NSString *loadedURL;

- (void) loadImageURL: (NSString*) url;
- (void) cancel;

@end
