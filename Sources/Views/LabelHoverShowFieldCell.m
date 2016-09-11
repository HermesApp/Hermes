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

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(nullable id)anObject event:(NSEvent *)theEvent {
  [[self controlView] setNeedsDisplay:YES];
  aRect = NSInsetRect([self drawingRectForBounds:controlView.bounds], 3, 0);
  // despite passing smaller rect to super, it ends up too wide the first time unless we set it explicitly
  NSDisableScreenUpdates(); // to prevent flashing of wider rect
  [super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event:theEvent];
  [textObj setFrameSize:aRect.size];
  NSEnableScreenUpdates();
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(nullable id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
  aRect = NSInsetRect([self drawingRectForBounds:controlView.bounds], 3, 0);
  // despite passing smaller rect to super, it ends up too wide the first time unless we set it explicitly
  NSDisableScreenUpdates(); // to prevent flashing of wider rect
  [super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
  [textObj setFrameSize:aRect.size];
  NSEnableScreenUpdates();
}

@end
