//
//  StationsTableView.m
//  Hermes
//
//  Created by Nicholas Riley on 9/14/13.
//
//

#import "StationsTableView.h"
#import "StationsController.h"
#import "HermesAppDelegate.h"
#import "PlaybackController.h"

@implementation StationsTableView

- (void)keyDown:(NSEvent *)theEvent {
  if ([[theEvent characters] isEqualToString:@"\r"]) {
    [playButton performClick:self];
  } else {
    [super keyDown:theEvent];
  }
}

@end
