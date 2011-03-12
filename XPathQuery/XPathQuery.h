//
//  XPathQuery.h
//  FuelFinder
//
//  Created by Matt Gallagher on 4/08/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#ifndef _XPATH_QUERY_H
#define _XPATH_QUERY_H

#include <libxml/parser.h>

NSArray* PerformXMLXPathQuery(NSData *document, NSString *query);
NSArray* PerformXPathQuery(xmlDocPtr doc, NSString *query);
xmlDocPtr parseXMLDocument(NSData *document);

#endif
