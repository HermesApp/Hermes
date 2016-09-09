//
//  MusicProgressSliderCell.m
//  Hermes
//
//  Created by Xinhong LIU on 19/4/15.
//
//

#import "MusicProgressSliderCell.h"

@implementation MusicProgressSliderCell

- (NSRect)knobRectFlipped:(BOOL)flipped {
  CGPoint sliderOrigin = [self barRectFlipped:false].origin;
  CGSize knobSize = CGSizeMake(2.0, 8.0); // this value is measured in iTunes App
  CGSize sliderSize = [self barRectFlipped:false].size;
  
  CGPoint knobOrigin;
  // truncf is important to make knob's border clear and sharp.
  knobOrigin.x = truncf(sliderOrigin.x + [self progressInPercentage]
                        * (sliderSize.width - knobSize.width));
  knobOrigin.y = sliderOrigin.y + sliderSize.height - knobSize.height;
  
  NSRect knobRect = NSMakeRect(knobOrigin.x, knobOrigin.y, knobSize.width, knobSize.height);
  return knobRect;
}

- (CGFloat)progressInPercentage {
  return (self.doubleValue - self.minValue) / (self.maxValue - self.minValue);
}

- (void)drawKnob:(NSRect)knobRect {
  [[self knobColor] setFill];
  NSRectFill(knobRect);
}

- (NSRect)barRectFlipped:(BOOL)flipped {
  NSRect barRect = [super barRectFlipped:flipped];
  barRect = NSInsetRect(barRect, -2, 0);

  CGFloat barHeight = 4.0; // this value is measured in iTunes App
  barRect.origin.y += (barRect.size.height - barHeight);
  barRect.size.height = barHeight;

  return barRect;
}

- (void)drawBarInside:(NSRect)barRect flipped:(BOOL)flipped {
  NSRect knobRect = [self knobRectFlipped:false];

  NSRect leftBarRect = barRect;
  leftBarRect.size.width = knobRect.origin.x - barRect.origin.x;
  [[self leftBarColor] setFill];
  NSRectFill(leftBarRect);

  NSRect rightBarRect = barRect;
  rightBarRect.origin.x = knobRect.origin.x;
  rightBarRect.size.width = barRect.origin.x + barRect.size.width - knobRect.origin.x;
  [[self rightBarColor] setFill];
  NSRectFill(rightBarRect);
}

// colors from iTunes 12.4
- (NSColor *)knobColor { return [NSColor blackColor]; }
- (NSColor *)leftBarColor { return [NSColor colorWithGenericGamma22White:112/255. alpha:1]; }
- (NSColor *)rightBarColor { return [NSColor colorWithGenericGamma22White:188/255. alpha:1]; }

@end
