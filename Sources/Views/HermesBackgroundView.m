//
//  HermesBackgroundView.m
//  Hermes
//
//  Created by Nicholas Riley on 9/9/16.
//
//

#import "HermesBackgroundView.h"

@implementation HermesBackgroundView

- (void)drawRect:(NSRect)dirtyRect {
  // work around ugly drawer background - doesn't seem to match any of the standard Apple system colors...
  [[NSColor colorWithGenericGamma22White:0.95 alpha:1] setFill];
  NSRectFill(dirtyRect);
}

@end
