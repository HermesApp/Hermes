//
//  LabelHoverShowField.m
//  Hermes
//
//  Created by Nicholas Riley on 5/22/16.
//
//

#import "LabelHoverShowField.h"
#import "LabelHoverShowFieldCell.h"

@implementation LabelHoverShowField

+ (void)initialize {
  [self setCellClass:[LabelHoverShowFieldCell class]];
}

- (void)mouseEntered:(NSEvent *)theEvent {
  [super mouseEntered:theEvent];
  [_hoverView setHidden:NO];
}

- (void)mouseExited:(NSEvent *)theEvent {
  [super mouseExited:theEvent];
  [_hoverView setHidden:YES];
}

- (void)resetCursorRects {
  if (_hoverView != nil) {
    NSRect hoverViewRect = [self convertRect:_hoverView.bounds fromView:_hoverView];
    [self addCursorRect:hoverViewRect cursor:[NSCursor arrowCursor]];
    NSRect boundsRect = self.bounds;
    NSRect intersectionRect = NSIntersectionRect(boundsRect, hoverViewRect);
    if (!NSIsEmptyRect(intersectionRect)) {
      if (intersectionRect.origin.x == 0)
        boundsRect.origin.x += intersectionRect.size.width;
      boundsRect.size.width -= intersectionRect.size.width;
    }
    [self addCursorRect:boundsRect cursor:[NSCursor IBeamCursor]];
  } else {
    [super resetCursorRects];
  }
}

- (void)updateTrackingAreas {
  if (_labelTrackingArea != nil) [self removeTrackingArea:_labelTrackingArea];

  _labelTrackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                    options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                                      owner:self
                                                   userInfo:nil];
  [self addTrackingArea:_labelTrackingArea];
}

@end
