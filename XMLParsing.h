//
//  XMLParsing.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#ifndef _XMLPARSING_H
#define _XMLPARSING_H

#include <libxml/parser.h>

xmlDocPtr parseXML(NSData *document);

#endif /* _XMLPARSING_H */
