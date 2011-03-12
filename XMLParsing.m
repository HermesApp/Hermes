//
//  XMLParsing.m
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#include <libxml2.h>
#import "XMLParsing.h"

NSArray *PerformXMLXPathQuery(NSData *document, NSString *query) {
    xmlDocPtr doc;

    /* Load XML document */
    doc = xmlReadMemory(
            [document bytes], [document length], "", NULL, XML_PARSE_RECOVER);

    if (doc == NULL)
    {
        NSLog(@"Unable to parse.");
        return nil;
    }

    NSArray *result = PerformXPathQuery(doc, query);
    xmlFreeDoc(doc);

    return result;
}

NSArray *PerformXPathQuery(xmlDocPtr doc, NSString *query) {
    xmlXPathContextPtr xpathCtx;
    xmlxpathObjectPtr xpathObj;

    /* Create XPath evaluation context */
    xpathCtx = xmlXPathNewContext(doc);
    if(xpathCtx == NULL)
    {
        NSLog(@"Unable to create XPath context.");
        return nil;
    }

    /* Evaluate XPath expression */
    xmlChar *queryString =
  (xmlChar *)[query cStringUsingEncoding:NSUTF8StringEncoding];
    xpathObj = xmlXPathEvalExpression(queryString, xpathCtx);
    if(xpathObj == NULL) {
        NSLog(@"Unable to evaluate XPath.");
        return nil;
    }

    xmlNodeSetPtr nodes = xpathObj->nodesetval;
    if (!nodes)
    {
        NSLog(@"Nodes was nil.");
        return nil;
    }

    NSMutableArray *resultNodes = [NSMutableArray array];
    for (NSInteger i = 0; i < nodes->nodeNr; i++)
    {
        NSDictionary *nodeDictionary = DictionaryForNode(nodes->nodeTab[i], nil);
        if (nodeDictionary)
        {
            [resultNodes addObject:nodeDictionary];
        }
    }

    /* Cleanup */
    xmlXPathFreeObject(xpathObj);
    xmlXPathFreeContext(xpathCtx);

    return resultNodes;
}
