//
//  NSDrawerWindow-HermesFirstResponderWorkaround.m
//  Hermes
//
//  Created by Nicholas Riley on 1/14/17.
//
//

#import <AppKit/AppKit.h>

// Work around regression in macOS 10.12 related to setting first responders in drawers.
// Based on code from <https://forums.developer.apple.com/thread/49052>.

@interface NSWindow (HermesFirstResponderWorkaround)
- (void)_setFirstResponder:(NSResponder *)responder;
@end

@interface NSDrawerWindow : NSWindow
@end

@implementation NSDrawerWindow (HermesFirstResponderWorkaround)
- (void)_setFirstResponder:(NSResponder *)responder {
  if (![responder isKindOfClass:[NSView class]] || [(NSView *)responder window] == self)
    [super _setFirstResponder:responder];
}
@end
