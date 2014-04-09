#import "PreferencesController.h"
#import "URLConnection.h"

@implementation URLConnection

static void URLConnectionStreamCallback(CFReadStreamRef aStream,
                                        CFStreamEventType eventType,
                                        void* _conn) {
  UInt8 buf[1024];
  int len;
  URLConnection* conn = (__bridge URLConnection*) _conn;
  conn->events++;

  switch (eventType) {
    case kCFStreamEventHasBytesAvailable:
      if ((len = CFReadStreamRead(aStream, buf, sizeof(buf))) > 0) {
        [conn->bytes appendBytes:buf length:len];
      }
      return;
    case kCFStreamEventErrorOccurred:
      conn->cb(nil, (__bridge_transfer NSError*) CFReadStreamCopyError(aStream));
      break;
    case kCFStreamEventEndEncountered: {
      conn->cb(conn->bytes, nil);
      break;
    }
    default:
      assert(0);
  }

  conn->cb = nil;
  [conn->timeout invalidate];
  conn->timeout = nil;
  CFReadStreamClose(conn->stream);
  CFRelease(conn->stream);
  conn->stream = nil;
}

- (void) dealloc {
  [timeout invalidate];
  if (stream != nil) {
    CFReadStreamClose(stream);
    CFRelease(stream);
  }
}

/**
 * @brief Creates a new instance for the specified request
 *
 * @param request the request to be sent
 * @param cb the callback to invoke when the request is done. If an error
 *        happened, then the data will be nil, and the error will be valid.
 *        Otherwise the data will be valid and the error will be nil.
 */
+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(void(^)(NSData*, NSError*)) cb {

  URLConnection *c = [[URLConnection alloc] init];

  /* Create the HTTP message to send */
  CFHTTPMessageRef message =
      CFHTTPMessageCreateRequest(NULL,
                                 (__bridge CFStringRef)[request HTTPMethod],
                                 (__bridge CFURLRef)   [request URL],
                                 kCFHTTPVersion1_1);

  /* Copy headers over */
  NSDictionary *headers = [request allHTTPHeaderFields];
  for (NSString *header in headers) {
    CFHTTPMessageSetHeaderFieldValue(message,
                         (__bridge CFStringRef) header,
                         (__bridge CFStringRef) headers[header]);
  }

  /* Also the http body */
  if ([request HTTPBody] != nil) {
    CFHTTPMessageSetBody(message, (__bridge CFDataRef) [request HTTPBody]);
  }
  c->stream = CFReadStreamCreateForHTTPRequest(NULL, message);
  CFRelease(message);

  /* Handle SSL connections */
  NSString *urlstring = [[request URL] absoluteString];
  if ([urlstring rangeOfString:@"https"].location == 0) {
    NSDictionary *settings =
    @{(id)kCFStreamSSLLevel: (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL,
     (id)kCFStreamSSLAllowsExpiredCertificates: @NO,
     (id)kCFStreamSSLAllowsExpiredRoots: @NO,
     (id)kCFStreamSSLAllowsAnyRoot: @NO,
     (id)kCFStreamSSLValidatesCertificateChain: @YES,
     (id)kCFStreamSSLPeerName: [NSNull null]};

    CFReadStreamSetProperty(c->stream, kCFStreamPropertySSLSettings,
                            (__bridge CFDictionaryRef) settings);
  }

  c->cb = [cb copy];
  c->bytes = [NSMutableData dataWithCapacity:100];
  [c setHermesProxy];
  return c;
}

/**
 * @brief Start sending this request to the server
 */
- (void) start {
  if (!CFReadStreamOpen(stream)) {
    assert(0);
  }
  CFStreamClientContext context = {0, (__bridge_retained void*) self, NULL,
                                   NULL, NULL};
  CFReadStreamSetClient(stream,
                        kCFStreamEventHasBytesAvailable |
                          kCFStreamEventErrorOccurred |
                          kCFStreamEventEndEncountered,
                        URLConnectionStreamCallback,
                        &context);
  CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),
                                  kCFRunLoopCommonModes);
  timeout = [NSTimer scheduledTimerWithTimeInterval:10
                                             target:self
                                           selector:@selector(checkTimeout)
                                           userInfo:nil
                                            repeats:YES];
}

- (void) checkTimeout {
  if (events > 0 || cb == nil || stream == NULL) {
    events = 0;
    return;
  }

  CFReadStreamClose(stream);
  CFRelease(stream);
  // FIXME: Most definitely a cause of "Internal Pandora Error".
  NSError *error = [NSError errorWithDomain:@"Connection timeout."
                                       code:0
                                   userInfo:nil];
  cb(nil, error);
  cb = nil;
}

- (void) setHermesProxy {
  [URLConnection setHermesProxy:stream];
}

/**
 * @brief Helper for setting whatever proxy is specified in the Hermes
 *        preferences
 */
+ (void) setHermesProxy:(CFReadStreamRef) stream {
  switch ([[NSUserDefaults standardUserDefaults] integerForKey:ENABLED_PROXY]) {
    case PROXY_HTTP:
      [self setHTTPProxy:stream
                     host:PREF_KEY_VALUE(PROXY_HTTP_HOST)
                     port:[PREF_KEY_VALUE(PROXY_HTTP_PORT) intValue]];
      break;

    case PROXY_SOCKS:
      [self setSOCKSProxy:stream
                     host:PREF_KEY_VALUE(PROXY_SOCKS_HOST)
                     port:[PREF_KEY_VALUE(PROXY_SOCKS_PORT) intValue]];
      break;

    case PROXY_SYSTEM:
    default:
      [self setSystemProxy:stream];
      break;
  }
}

+ (void) setHTTPProxy:(CFReadStreamRef)stream
                 host:(NSString*)host
                 port:(NSInteger)port {
  CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
      host, kCFStreamPropertyHTTPProxyHost,
      [NSNumber numberWithInt:port], kCFStreamPropertyHTTPProxyPort,
      nil];
  CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
}

+ (void) setSOCKSProxy:(CFReadStreamRef)stream
                 host:(NSString*)host
                 port:(NSInteger)port {
  CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
      host, kCFStreamPropertySOCKSProxyHost,
      [NSNumber numberWithInt:port], kCFStreamPropertySOCKSProxyPort,
      nil];
  CFReadStreamSetProperty(stream, kCFStreamPropertySOCKSProxy, proxySettings);
}

+ (void) setSystemProxy:(CFReadStreamRef)stream {
  CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
  CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
  CFRelease(proxySettings);
}

@end
