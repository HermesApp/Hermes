//
//  HistoryView.m
//  Hermes
//
//  Created by Alex Crichton on 6/29/12.
//

#import "HistoryView.h"

@implementation HistoryView

@synthesize selected;

- (NSView *)hitTest:(NSPoint)aPoint {
  // don't allow any mouse clicks for subviews
  return nil;
}

- (void)setTextColor:(NSColor *)color {
  for (NSView *view in [self subviews]) {
    if ([view respondsToSelector:@selector(setTextColor:)]) {
      [(id)view setTextColor:color];
    }
  }
}

- (void)drawRect:(NSRect)dirtyRect {
  // Don't allow partial redraws (e.g. when switching drawer): it produces artifacts
  if (!NSEqualPoints(dirtyRect.origin, NSZeroPoint)) {
    [self setNeedsDisplay:YES];
  }
  if (selected) {
    if ([[self window] firstResponder] != [self superview]) {
      [[NSColor secondarySelectedControlColor] set];
      [self setTextColor:[NSColor controlTextColor]];
    } else {
      [[NSColor alternateSelectedControlColor] set];
      [self setTextColor:[NSColor alternateSelectedControlTextColor]];
    }
    NSRectFill([self bounds]);
  } else {
    [self setTextColor:[NSColor controlTextColor]];
  }
}

@end
