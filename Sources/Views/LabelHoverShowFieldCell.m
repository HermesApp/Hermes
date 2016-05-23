//
//  LabelHoverShowFieldCell.m
//  Hermes
//
//  Created by Nicholas Riley on 5/22/16.
//
//

#import "LabelHoverShowFieldCell.h"
#import "LabelHoverShowField.h"

@implementation LabelHoverShowFieldCell

- (NSRect)drawingRectForBounds:(NSRect)theRect {
  NSRect drawingRect = [super drawingRectForBounds:theRect];

  NSView *hoverView = ((LabelHoverShowField *)self.controlView).hoverView;
  if (hoverView != nil) {
    CGFloat hoverViewWidth = hoverView.frame.size.width;
    drawingRect.origin.x += hoverViewWidth;
    drawingRect.size.width -= 2 * hoverViewWidth;
  }

  return drawingRect;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
  aRect = NSInsetRect([self drawingRectForBounds:controlView.bounds], 2, 0);
  [super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(nullable id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
  aRect = NSInsetRect([self drawingRectForBounds:controlView.bounds], 2, 0);
  [super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

@end
