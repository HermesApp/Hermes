//
//  MusicProgressSlider.m
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

- (void)drawBarInside:(NSRect)aRect flipped:(BOOL)flipped {
  NSRect barRect = aRect;
  CGFloat barHeight = 4.0; // this value is measured in iTunes App
  barRect.origin.y += (barRect.size.height - barHeight);
  barRect.size.height = barHeight;
  
  NSRect leftRect = [self leftBarRectInsideBarRect:barRect];
  [[self leftBarColor] setFill];
  NSRectFill(leftRect);
  
  NSRect rightRect = [self rightBarRectInsideBarRect:barRect];
  [[self rightBarColor] setFill];
  NSRectFill(rightRect);
}

- (NSRect)leftBarRectInsideBarRect:(NSRect)barRect {
  NSRect knobRect = [self knobRectFlipped:false];
  NSRect leftBarRect = barRect;
  leftBarRect.size.width = knobRect.origin.x - barRect.origin.x;
  return leftBarRect;
}

- (NSRect)rightBarRectInsideBarRect:(NSRect)barRect {
  NSRect knobRect = [self knobRectFlipped:false];
  NSRect rightBarRect = barRect;
  rightBarRect.origin.x = knobRect.origin.x;
  rightBarRect.size.width = barRect.origin.x + barRect.size.width
                            - knobRect.origin.x;
  return rightBarRect;
}

- (NSColor *)knobColor {
  // this color value is measured in iTunes App
  return [NSColor colorWithRed:4.0/255.0 green:4.0/255.0 blue:4.0/255.0 alpha:1.0];
}

- (NSColor *)leftBarColor {
  // this color value is measured in iTunes App
  return [NSColor colorWithRed:93.0/255.0 green:93.0/255.0 blue:93.0/255.0 alpha:1.0];
}

- (NSColor *)rightBarColor {
  // this color value is measured in iTunes App
  return [NSColor colorWithRed:174.0/255.0 green:174.0/255.0 blue:174.0/255.0 alpha:1.0];
}

@end
