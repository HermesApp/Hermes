#import "API.h"
#import "Crypt.h"

#include <libxml/xpath.h>
#include <string.h>

@implementation PandoraRequest

@synthesize requestData, requestMethod, info, responseData, callback;

+ (PandoraRequest*) requestWithMethod: (NSString*) method
                                 data: (NSString*) data
                             callback: (PandoraCallback) callback {
  PandoraRequest *req = [[PandoraRequest alloc] init];
  [req setCallback:[callback copy]];
  [req setRequestData:data];
  [req setRequestMethod:method];
  [req resetResponse];

  return req;
}

- (void) resetResponse {
  [self setResponseData:[NSMutableData dataWithCapacity:1024]];
}

- (void) replaceAuthToken:(NSString*)token with:(NSString*)replacement {
  NSString *new_data = [requestData stringByReplacingOccurrencesOfString:token
                                                              withString:replacement];
  [self setRequestData:new_data];
}

@end

BOOL xpathNodes(xmlDocPtr doc, char* xpath, void (^callback)(xmlNodePtr)) {
  BOOL success = NO;
  xmlXPathContextPtr xpathCtx;
  xmlXPathObjectPtr xpathObj;
  
  /* Create xpath evaluation context */
  xpathCtx = xmlXPathNewContext(doc);
  if (xpathCtx == NULL) {
    return NO;
  }
  
  /* Evaluate xpath expression */
  xpathObj = xmlXPathEvalExpression((xmlChar *)xpath, xpathCtx);
  if (xpathObj == NULL) {
    goto doneContext;
  }

  xmlNodeSetPtr nodes = xpathObj->nodesetval;
  if (!nodes) {
    goto done;
  }

  for (NSInteger i = 0; i < nodes->nodeNr; i++) {
    callback(nodes->nodeTab[i]);
  }
  
done:
  /* Cleanup */
  xmlXPathFreeObject(xpathObj);
doneContext:
  xmlXPathFreeContext(xpathCtx);
  return success;
}

NSString* xpathRelative(xmlDocPtr doc, char* xpath, xmlNodePtr node) {
  NSString *result = nil;
  xmlXPathContextPtr xpathCtx;
  xmlXPathObjectPtr xpathObj;

  /* Create xpath evaluation context */
  xpathCtx = xmlXPathNewContext(doc);
  if (xpathCtx == NULL) {
    return nil;
  }
  xpathCtx->node = node;

  /* Evaluate xpath expression */
  xpathObj = xmlXPathEvalExpression((xmlChar *)xpath, xpathCtx);
  if (xpathObj == NULL) {
    xmlXPathFreeContext(xpathCtx);
    return nil;
  }

  xmlNodeSetPtr nodes = xpathObj->nodesetval;
  if (!nodes || nodes->nodeNr < 1) {
    goto done;
  }
  xmlNodePtr child = nodes->nodeTab[0];
  char *content;
  if (child->children == NULL || child->children->content == NULL) {
    content = "";
  } else {
    content = (char*) child->children->content;
  }
  result = [NSString stringWithCString:content
                              encoding:NSUTF8StringEncoding];

done:
  /* Cleanup */
  xmlXPathFreeObject(xpathObj);
  xmlXPathFreeContext(xpathCtx);
  return result;
}

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
 * Sends a request to the server and parses the response as XML
 */
- (BOOL) sendRequest: (PandoraRequest*) request {
  NSString *method = [request requestMethod];
  NSString *time = [NSString stringWithFormat:@"%d", [self time]];
  NSString *rid  = [time substringFromIndex: 3];
  NSString *url  = [NSString stringWithFormat:
      @"https://" PANDORA_API_HOST PANDORA_API_PATH PANDORA_API_VERSION
      @"?rid=%@P&method=%@", rid, method];

  if (![method isEqual: @"sync"] && ![method isEqual: @"authenticateListener"]) {
    NSString *lid = [NSString stringWithFormat:@"&lid=%@", listenerID];
    url = [url stringByAppendingString:lid];
  }

  /* Prepare the request */
  NSURL *nsurl = [NSURL URLWithString:url];
  NSMutableURLRequest *nsrequest = [NSMutableURLRequest requestWithURL:nsurl];

  [nsrequest setHTTPMethod: @"POST"];
  [nsrequest addValue: @"application/xml" forHTTPHeaderField: @"Content-Type"];

  /* Create the body */
  NSString *encrypted_data = PandoraEncrypt([request requestData]);
  [nsrequest setHTTPBody:[encrypted_data dataUsingEncoding:NSUTF8StringEncoding]];

  /* Fetch the response asynchronously */
  NSURLConnection *conn = [[NSURLConnection alloc]
    initWithRequest:nsrequest delegate:self];

  [activeRequests setObject:request
    forKey:[NSNumber numberWithInteger: [conn hash]]];

  return YES;
}

/* Helper method for getting the PandoraRequest for a connection */
- (PandoraRequest*) dataForConnection: (NSURLConnection*)connection {
  return [activeRequests objectForKey:
      [NSNumber numberWithInteger:[connection hash]]];
}

/* Cleans up the specified connection with the parsed XML. This method will
   check the document for errors (if the document exists. The error event
   will be published through the default NSNotificationCenter, or the
   callback for the connection will be invoked */
- (void)cleanupConnection:(NSURLConnection *)connection : (xmlDocPtr)doc : (NSString*) fault {
  PandoraRequest *request = [self dataForConnection:connection];

  if (doc != NULL && fault == nil) {
    fault = xpathRelative(doc, "//fault//member[name='faultString']/value", NULL);
  }

  if (doc == NULL || fault != nil) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (doc == NULL) {
      fault = @"Connection error";
    } else {
      NSArray *parts = [fault componentsSeparatedByString:@"|"];
      if ([parts count] >= 3) {
        fault = [parts objectAtIndex:2];
      }
    }
    NSLogd(@"Fault: %@", fault);

    [info setValue:request forKey:@"request"];
    [info setValue:fault   forKey:@"error"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hermes.pandora-error"
                                                        object:self
                                                      userInfo:info];
  } else {
    /* Only invoke the callback if there's no faults */
    [request callback](doc);
  }

  /* Always free these up */
  [activeRequests removeObjectForKey:[NSNumber numberWithInteger: [connection hash]]];
  if (doc != NULL) {
    xmlFreeDoc(doc);
  }
}

/* Collect the data received */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  PandoraRequest *request = [self dataForConnection:connection];
  [[request responseData] appendData:data];
}

/* Immediately cleans up if we have a bad response */
- (void)connection:(NSURLConnection *)connection
    didReceiveResponse:(NSHTTPURLResponse *)response {
  if ([response statusCode] < 200 || [response statusCode] >= 300) {
    [connection cancel];
    [self cleanupConnection:connection : NULL : @"Didn't receive 2xx response"];
  }
}

/* Immediately cleans up the connection with no XML document */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [self cleanupConnection:connection : NULL : [error localizedDescription]];
}

/* Parses the XML received from the connection, then cleans up */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  PandoraRequest *request = [self dataForConnection:connection];

  xmlDocPtr doc = xmlReadMemory([[request responseData] bytes],
                                [[request responseData] length],
                                "",
                                NULL,
                                XML_PARSE_RECOVER);
  [self cleanupConnection:connection : doc : nil];
}

@end
