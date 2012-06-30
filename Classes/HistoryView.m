//
//  HistoryView.m
//  Hermes
//
//  Created by Alex Crichton on 6/29/12.
//

#import "HistoryView.h"

@implementation HistoryView

@synthesize selected;

- (void)drawRect:(NSRect)dirtyRect {
  if (selected) {
    [[NSColor selectedControlColor] set];
    NSRectFill([self bounds]);
  }
}

@end
