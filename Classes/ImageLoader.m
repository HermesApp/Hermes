#import "ImageLoader.h"

@implementation ImageLoader

@synthesize data, loadedURL;

- (void) dealloc {
  if (prev != nil) {
    [prev cancel];
    [prev release];
  }
  [super dealloc];
}

- (void) notifyImageLoaded {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"image-loaded"
                                                      object:self];
}

- (void) loadImageURL: (NSString*) url {
  if (prev != nil) {
    [prev cancel];
    [prev release];
  }

  [self setLoadedURL:url];

  [self setData:[NSMutableData data]];

  NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  prev = [[NSURLConnection alloc] initWithRequest:req delegate:self];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)d {
  [data appendData:d];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveResponse:(NSHTTPURLResponse *)response {

  if ([response statusCode] < 200 || [response statusCode] >= 300) {
    [connection cancel];
    [self notifyImageLoaded];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [self notifyImageLoaded];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  [self notifyImageLoaded];
}

@end
