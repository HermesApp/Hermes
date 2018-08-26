#import "PreferencesController.h"
#import "URLConnection.h"

NSString * const URLConnectionProxyValidityChangedNotification = @"URLConnectionProxyValidityChangedNotification";

@implementation URLConnection

static void URLConnectionStreamCallback(CFReadStreamRef aStream,
                                        CFStreamEventType eventType,
                                        void* _conn) {
  UInt8 buf[1024];
  CFIndex len;
  URLConnection* conn = (__bridge URLConnection*) _conn;
  conn->events++;

  switch (eventType) {
    case kCFStreamEventHasBytesAvailable:
      while ((len = CFReadStreamRead(aStream, buf, sizeof(buf))) > 0) {
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
     (id)kCFStreamSSLValidatesCertificateChain: @NO,
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
  CFReadStreamOpen(stream);
  CFStreamStatus streamStatus = CFReadStreamGetStatus(stream);
  if (streamStatus == kCFStreamStatusError) {
    cb(nil, (NSError *)CFBridgingRelease(CFReadStreamCopyError(stream)));
    return;
  }
  if (streamStatus != kCFStreamStatusOpen)
    NSLog(@"Expected read stream to be open, but it was not (%ld)", (long)streamStatus);

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
  switch (PREF_KEY_INT(ENABLED_PROXY)) {
    case PROXY_HTTP:
      [self setHTTPProxy:stream
                    host:PREF_KEY_VALUE(PROXY_HTTP_HOST)
                    port:PREF_KEY_INT(PROXY_HTTP_PORT)];
      break;

    case PROXY_SOCKS:
      [self setSOCKSProxy:stream
                     host:PREF_KEY_VALUE(PROXY_SOCKS_HOST)
                     port:PREF_KEY_INT(PROXY_SOCKS_PORT)];
      break;

    case PROXY_SYSTEM:
    default:
      [self setSystemProxy:stream];
      break;
  }
}

+ (BOOL)validProxyHost:(NSString **)host port:(NSInteger)port {
  static BOOL wasValid = YES;
  *host = [*host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  BOOL isValid = ((port > 0 && port <= 65535) && [NSHost hostWithName:*host].address != nil);
  if (isValid != wasValid) {
    [[NSNotificationCenter defaultCenter] postNotificationName:URLConnectionProxyValidityChangedNotification
                                                        object:nil
                                                      userInfo:@{@"isValid": @(isValid)}];
    wasValid = isValid;
  }
  return isValid;
}

+ (BOOL) setHTTPProxy:(CFReadStreamRef)stream
                 host:(NSString*)host
                 port:(NSInteger)port {
  if (![self validProxyHost:&host port:port]) return NO;
  CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
          [NSDictionary dictionaryWithObjectsAndKeys:
                  host, kCFStreamPropertyHTTPProxyHost,
                  @(port), kCFStreamPropertyHTTPProxyPort,
                  host, kCFStreamPropertyHTTPSProxyHost,
                  @(port), kCFStreamPropertyHTTPSProxyPort,
                  nil];
  CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
  return YES;
}

+ (BOOL) setSOCKSProxy:(CFReadStreamRef)stream
                 host:(NSString*)host
                 port:(NSInteger)port {
  if (![self validProxyHost:&host port:port]) return NO;
  CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
          [NSDictionary dictionaryWithObjectsAndKeys:
                  host, kCFStreamPropertySOCKSProxyHost,
                  @(port), kCFStreamPropertySOCKSProxyPort,
                  nil];
  CFReadStreamSetProperty(stream, kCFStreamPropertySOCKSProxy, proxySettings);
  return YES;
}

+ (void) setSystemProxy:(CFReadStreamRef)stream {
  CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
  CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
  CFRelease(proxySettings);
}

@end
