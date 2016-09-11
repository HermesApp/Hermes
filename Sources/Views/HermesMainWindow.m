//
//  HermesMainWindow.m
//  Hermes
//
//  Created by Nicholas Riley on 9/10/16.
//
//

#import "HermesMainWindow.h"

@implementation HermesMainWindow

- (void)sendEvent:(NSEvent *)theEvent {
  if ([theEvent type] == NSKeyDown) {

    // don't ever let space bar get through to the field editor so it can be used for play/pause
    if ([[theEvent characters] isEqualToString:@" "] && ([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == 0) {
      [[NSApp mainMenu] performKeyEquivalent:theEvent];
      return;
    }
  }
  [super sendEvent:theEvent];
}

@end
