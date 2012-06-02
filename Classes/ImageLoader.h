@interface ImageLoader : NSObject {
  NSURLConnection *prev;
  NSMutableData *data;
  NSString *loadedURL;
}

@property (retain) NSMutableData *data;
@property (retain) NSString *loadedURL;

- (void) loadImageURL: (NSString*) url;
- (void) cancel;

@end
