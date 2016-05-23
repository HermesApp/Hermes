//
//  LabelHoverShowField.h
//  Hermes
//
//  Created by Nicholas Riley on 5/22/16.
//
//

#import <Cocoa/Cocoa.h>

@interface LabelHoverShowField : NSTextField
{
  NSTrackingArea *_labelTrackingArea;
}

@property (nonatomic) IBOutlet NSView *hoverView;

@end
