//
//  HistoryCollectionView.m
//  Hermes
//
//  Created by Winston Weinert on 1/1/14.
//
//

#import "HistoryCollectionView.h"
#import "HermesAppDelegate.h"
#import "PlaybackController.h"

@implementation HistoryCollectionView

- (void)keyDown:(NSEvent *)theEvent {
  if ([[theEvent characters] isEqualToString:@" "]) {
    [[HMSAppDelegate playback] playpause:nil];
  } else {
    [super keyDown:theEvent];
  }
}

@end
