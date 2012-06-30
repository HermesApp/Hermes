//
//  HistoryItem.m
//  Hermes
//
//  Created by Alex Crichton on 10/10/11.
//

#import "HistoryController.h"
#import "HistoryItem.h"
#import "HistoryView.h"
#import "ImageLoader.h"
#import "Pandora.h"
#import "Pandora/Song.h"

@implementation HistoryItem

- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setSelected:(BOOL)selected {
  [super setSelected:selected];
  HistoryView *view = (HistoryView*) [self view];
  [view setSelected:selected];
  [view setNeedsDisplay:YES];
  HistoryController *hc = [[self collectionView] delegate];
  [hc updateThumbs];
}

- (void) updateUI {
  if (art == nil || [self representedObject] == nil) {
    return;
  }

  Song *s = [self representedObject];
  NSString *a = [s art];
  if (a && ![a isEqual:@""]) {
    [[ImageLoader loader] loadImageURL:a callback:^(NSData* data) {
      NSImage *image = [[NSImage alloc] initWithData: data];
      [art setImage:image];
    }];
  }
}

- (void) trySetFromView {
  NSView *view = [self view];
  if (view == nil) {
    return;
  }

  art = nil;
  for (NSView *view in [[self view] subviews]) {
    if ([view isKindOfClass:[NSButton class]]) {
      NSButton *button = (NSButton*) view;
      if ([[button alternateTitle] isEqual:@"Album"]) {
        art = button;
      }
    }
  }
  assert(art);
}

- (void) setView:(NSView *)view {
  [super setView:view];
  [self trySetFromView];
}

- (void) setRepresentedObject:(id)representedObject {
  [super setRepresentedObject:representedObject];
  [self trySetFromView];
  [self updateUI];
}

@end
