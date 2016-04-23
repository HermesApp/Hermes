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
  // XXX work around bug in OS X 10.7–10.11 where the Credits text is not centered (r. 14829080)
  NSSet *windowsBefore = [NSSet setWithArray:[NSApp windows]];

  // change credits font to current system font
  NSData *creditsData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]];
  NSMutableAttributedString *credits = [[NSMutableAttributedString alloc] initWithRTF:creditsData documentAttributes:nil];
  NSString *systemFontFamily = [[NSFont systemFontOfSize:[NSFont labelFontSize]].fontDescriptor objectForKey:NSFontFamilyAttribute];

  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSRange effectiveRange = {0, 0};
  NSUInteger length = credits.length;
  while (NSMaxRange(effectiveRange) < length) {
    NSFont *font = [credits attribute:NSFontAttributeName atIndex:NSMaxRange(effectiveRange) effectiveRange:&effectiveRange];
    font = [fontManager convertFont:font toFamily:systemFontFamily];
    [credits addAttribute:NSFontAttributeName value:font range:effectiveRange];
  }

  NSMutableDictionary *optionsWithCredits = optionsDictionary == nil ? [[NSMutableDictionary alloc] initWithCapacity:1] : [optionsDictionary mutableCopy];
  optionsWithCredits[@"Credits"] = credits;

  [super orderFrontStandardAboutPanelWithOptions:optionsWithCredits];

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
