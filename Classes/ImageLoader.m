#import "ImageLoader.h"
#import "URLConnection.h"

@implementation ImageLoader

@synthesize data, loadedURL;

- (void) loadImageURL: (NSString*) url {
  [self cancel];
  [self setLoadedURL:url];

  NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  prev = [URLConnection connectionForRequest:req
                           completionHandler:^(NSData *d, NSError *error) {
    data = d;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"image-loaded"
                                                        object:self];
  }];
  [prev start];
}

- (void) cancel {
  prev = nil;
}

@end
