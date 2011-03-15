//
//  API.m
//  Hermes
//
//  Created by Alex Crichton on 3/15/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "API.h"

#include <libxml/xpath.h>
#include <string.h>

@implementation API

@synthesize listenerID;

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
    [ret retain];
  }

  //  [arr release];
  return ret;
}

/**
 * Sends a request to the server and parses the response as XML
 */
- (xmlDocPtr) sendRequest: (NSString*)method : (NSString*)data {
  NSString *time = [NSString stringWithFormat:@"%d", [self time]];
  NSString *rid  = [time substringFromIndex: 3];

  NSString *url = [NSString stringWithFormat:
                   @"http://www.pandora.com/radio/xmlrpc/v29?rid=%@P&method=%@", rid, method];

  if (![method isEqual: @"sync"] && ![method isEqual: @"authenticateListener"]) {
    NSString *lid = [NSString stringWithFormat:@"lid=%@", listenerID];
    url = [url stringByAppendingString:lid];
  }

  // Prepare the request
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

  [request setURL: [NSURL URLWithString:url]];
  [request setHTTPMethod: @"POST"];
  [request addValue: @"application/xml" forHTTPHeaderField: @"Content-Type"];

  // Create the body
  NSMutableData *postBody = [NSMutableData data];
  [postBody appendData: [data dataUsingEncoding:NSUTF8StringEncoding]];
  [request setHTTPBody:postBody];

  // get response
  NSHTTPURLResponse *urlResponse = nil;
  NSError *error = [[NSError alloc] init];
  NSData *responseData = [NSURLConnection sendSynchronousRequest:request
                                               returningResponse:&urlResponse error:&error];

  if ([urlResponse statusCode] < 200 || [urlResponse statusCode] >= 300) {
    responseData = nil;
  }

  [request release];
  [error release];

  if (responseData == nil) {
    return NULL;
  }

  xmlDocPtr doc = xmlReadMemory([responseData bytes], [responseData length], "",
                                NULL, XML_PARSE_RECOVER);
  NSArray *fault = [self xpath: doc : "//methodResponse/fault"];

  if ([fault count] > 0) {
    NSString *resp = [[NSString alloc] initWithData:responseData
                                           encoding:NSASCIIStringEncoding];
    NSLog(@"Fault!: %@", resp);
    xmlFreeDoc(doc);
    return NULL;
  }

  return doc;
}

@end
