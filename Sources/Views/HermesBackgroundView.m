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
  // work around ugly drawer background on 10.10
  // - doesn't seem to match any of the standard Apple system colors...
  if (NSAppKitVersionNumber <= NSAppKitVersionNumber10_10_Max) {
    [[NSColor colorWithGenericGamma22White:241/255. alpha:1] setFill];
    NSRectFill(dirtyRect);
  } else if (NSAppKitVersionNumber > NSAppKitVersionNumber10_13_4) {
    // XXX should be using NSVisualEffectView instead
    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(dirtyRect);
  }
}

@end
