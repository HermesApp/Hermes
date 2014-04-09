//
//  HermesApp.m
//  Hermes
//
//  Created by Nicholas Riley on 4/1/14.
//
//

#import "HermesApp.h"

@implementation HermesApp

- (void)orderFrontStandardAboutPanelWithOptions:(NSDictionary *)optionsDictionary {
  // XXX work around bug in OS X 10.7 / 10.8 where the Credits text is not centered (r. 14829080)
  NSSet *windowsBefore = [NSSet setWithArray:[NSApp windows]];

  [super orderFrontStandardAboutPanelWithOptions:optionsDictionary];

  for (NSWindow *window in [NSApp windows]) {
    if ([windowsBefore containsObject:window])
      continue;

    for (NSView *view in [[window contentView] subviews]) {
      if (![view isKindOfClass:[NSScrollView class]])
        continue;

      NSClipView *clipView = [(NSScrollView *)view contentView];
      NSRect clipViewFrame = [clipView frame];
      NSView *documentView = [clipView documentView];
      NSRect documentViewFrame = [documentView frame];

      if (clipViewFrame.size.height != documentViewFrame.size.height)
        continue; // don't mess with a scrollable view

      if (clipViewFrame.size.width != documentViewFrame.size.width) {
        documentViewFrame.size.width = clipViewFrame.size.width;
        [documentView setFrame:documentViewFrame];
        break;
      }
    }
    break;
  }
}

@end
