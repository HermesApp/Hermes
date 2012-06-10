#import "ImageLoader.h"
#import "URLConnection.h"

@implementation ImageLoader

+ (ImageLoader*) loader {
  static ImageLoader *l = nil;
  if (l == nil) {
    l = [[ImageLoader alloc] init];
  }
  return l;
}

- (id) init {
  cur = nil;
  queue = [NSMutableArray array];
  cbqueue = [NSMutableArray array];
  return self;
}

- (void) loadImageURL:(NSString*)url callback:(ImageCallback)cb {
  cb = [cb copy];
  if (cur != nil) {
    [queue addObject:url];
    [cbqueue addObject:cb];
    NSLogd(@"queueing %@", url);
    return;
  }

  [self fetch:url cb:cb];
}

- (void) fetch:(NSString*)url cb:(ImageCallback)cb {
  NSLogd(@"fetching: %@", url);
  NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  cur = [URLConnection connectionForRequest:req
                          completionHandler:^(NSData *d, NSError *error) {
    cb(d);
    cur = nil;
    curURL = nil;
    [self tryFetch];
  }];
  curURL = url;
  [cur start];
}

- (void) tryFetch {
  if ([queue count] == 0) return;
  NSString *url = [queue objectAtIndex:0];
  ImageCallback cb = [cbqueue objectAtIndex:0];
  [queue removeObjectAtIndex:0];
  [cbqueue removeObjectAtIndex:0];
  [self fetch:url cb:cb];
}

- (void) cancel:(NSString*)url {
  NSUInteger idx = [queue indexOfObject:url];
  if (idx == NSNotFound) {
    if ([url isEqualToString:curURL]) {
      cur = nil;
      curURL = nil;
      [self tryFetch];
    }
  } else {
    [queue removeObjectAtIndex:idx];
    [cbqueue removeObjectAtIndex:idx];
  }
}

@end
