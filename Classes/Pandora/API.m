#import "API.h"

#include <libxml/xpath.h>
#include <string.h>

@implementation ConnectionData
@synthesize callback, data, info;

- (void) dealloc {
  [data release];
  [info release];
  [super dealloc];
}

@end

@implementation API

@synthesize listenerID;

- (id) init {
  activeRequests = [[NSMutableDictionary alloc] init];
  return [super init];
}

/**
 * Gets the current UNIX time
 */
- (int) time {
  return [[NSDate date] timeIntervalSince1970];
}

/**
 * Performs and XPATH query on the specified document, returning the array of
 * contents for each node matched
 */
- (NSArray*) xpath: (xmlDocPtr) doc : (char*) xpath {
  xmlXPathContextPtr xpathCtx;
  xmlXPathObjectPtr xpathObj;

  /* Create xpath evaluation context */
  xpathCtx = xmlXPathNewContext(doc);
  if(xpathCtx == NULL) {
    return nil;
  }

  /* Evaluate xpath expression */
  xpathObj = xmlXPathEvalExpression((xmlChar *)xpath, xpathCtx);
  if(xpathObj == NULL) {
    xmlXPathFreeContext(xpathCtx);
    return nil;
  }

  xmlNodeSetPtr nodes = xpathObj->nodesetval;
  if (!nodes) {
    xmlXPathFreeContext(xpathCtx);
    xmlXPathFreeObject(xpathObj);
    return nil;
  }

  NSMutableArray *resultNodes = [NSMutableArray array];
  char *content;
  for (NSInteger i = 0; i < nodes->nodeNr; i++) {
    if (nodes->nodeTab[i]->children == NULL || nodes->nodeTab[i]->children->content == NULL) {
      content = "";
    } else {
      content = (char*) nodes->nodeTab[i]->children->content;
    }

    NSString *str = [NSString stringWithCString: content encoding:NSUTF8StringEncoding];

    [resultNodes addObject: str];
  }

  /* Cleanup */
  xmlXPathFreeObject(xpathObj);
  xmlXPathFreeContext(xpathCtx);

  return resultNodes;
}

/**
 * Performs and xpath query and returns the content of the first node
 */
- (NSString*) xpathText: (xmlDocPtr)doc : (char*) xpath {
  NSArray  *arr = [self xpath: doc : xpath];
  NSString *ret = nil;

  if (arr != nil && [arr objectAtIndex: 0] != nil) {
    ret = [arr objectAtIndex: 0];
  }

  return ret;
}

- (BOOL) sendRequest: (NSString*)method : (NSString*)data : (SEL)callback {
  return [self sendRequest:method : data : callback : nil];
}

/**
 * Sends a request to the server and parses the response as XML
 */
- (BOOL) sendRequest: (NSString*)method : (NSString*)data : (SEL)callback : (id)info {
  NSString *time = [NSString stringWithFormat:@"%d", [self time]];
  NSString *rid  = [time substringFromIndex: 3];
  NSString *url  = [NSString stringWithFormat:
      @"http://" PANDORA_API_HOST PANDORA_API_PATH PANDORA_API_VERSION
      @"?rid=%@P&method=%@", rid, method];

  if (![method isEqual: @"sync"] && ![method isEqual: @"authenticateListener"]) {
    NSString *lid = [NSString stringWithFormat:@"&lid=%@", listenerID];
    url = [url stringByAppendingString:lid];
  }

  // Prepare the request
  NSURL *nsurl = [NSURL URLWithString:url];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsurl];

  [request setHTTPMethod: @"POST"];
  [request addValue: @"application/xml" forHTTPHeaderField: @"Content-Type"];

  // Create the body
  [request setHTTPBody:[data dataUsingEncoding:NSUTF8StringEncoding]];

  // Fetch the response asynchronously, storing the callback information we're
  // going to call at the end.
  NSURLConnection *conn = [[NSURLConnection alloc]
    initWithRequest:request delegate:self];

  ConnectionData *conn_data = [[ConnectionData alloc] init];
  [conn_data setCallback:callback];
  [conn_data setData:[NSMutableData dataWithCapacity:1024]];
  [conn_data setInfo:info];

  [activeRequests setObject:conn_data
    forKey:[NSNumber numberWithInteger: [conn hash]]];

  return YES;
}

- (ConnectionData*) dataForConnection: (NSURLConnection*)connection {
  return [activeRequests objectForKey:
      [NSNumber numberWithInteger:[connection hash]]];
}

- (void)cleanupConnection:(NSURLConnection *)connection : (xmlDocPtr)doc {
  ConnectionData *cdata = [self dataForConnection:connection];

  NSString *fault = nil;
  if (doc != NULL) {
    fault = [self xpathText: doc : "//fault//member[name='faultString']/value"];
  }

  if (doc == NULL || fault != nil) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setValue:cdata forKey:@"connection-data"];
    if (doc == NULL) {
      [info setValue:@"Connection error" forKey:@"error"];
    } else {
      NSArray *parts = [fault componentsSeparatedByString:@"|"];
      if ([parts count] >= 3) {
        fault = [parts objectAtIndex:2];
      }
      [info setValue:fault forKey:@"error"];
    }
    NSLogd(@"Fault: %@", fault);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hermes.pandora-error"
                                                        object:self
                                                      userInfo:info];
  } else {
    SEL selector = [cdata callback];
    id info = [cdata info];
    [self performSelector:selector withObject:(id)doc withObject:info];
  }

  [activeRequests removeObjectForKey:[NSNumber numberWithInteger: [connection hash]]];
  if (doc != NULL) {
    xmlFreeDoc(doc);
  }
  [connection release];
  [cdata release];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  ConnectionData *cdata = [self dataForConnection:connection];
  [[cdata data] appendData:data];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveResponse:(NSHTTPURLResponse *)response {
  if ([response statusCode] < 200 || [response statusCode] >= 300) {
    [connection cancel];
    [self cleanupConnection:connection : NULL];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [self cleanupConnection:connection : NULL];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  ConnectionData *cdata = [self dataForConnection:connection];

  xmlDocPtr doc = xmlReadMemory([[cdata data] bytes], [[cdata data] length], "",
                                NULL, XML_PARSE_RECOVER);

  [self cleanupConnection:connection : doc];
}

@end
