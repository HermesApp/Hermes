//
//  PlaybackController.h
//  Hermes
//
//  Created by Alex Crichton on 3/15/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Station.h"
#import "ImageLoader.h"

@interface PlaybackController : NSObject {
  IBOutlet NSProgressIndicator *songLoadingProgress;

  IBOutlet NSTextField *artistLabel;
  IBOutlet NSTextField *songLabel;
  IBOutlet NSTextField *progressLabel;
  IBOutlet NSProgressIndicator *playbackProgress;
  IBOutlet NSImageView *art;

  NSTimer *progressUpdateTimer;
  ImageLoader *loader;

  // Liking/Disliking/Tired
  IBOutlet NSToolbarItem *like;
  IBOutlet NSToolbarItem *dislike;
  IBOutlet NSToolbarItem *tired;

  // Toolbar Items
  IBOutlet NSToolbarItem *playpause;
  IBOutlet NSToolbarItem *next;
  IBOutlet NSToolbar *toolbar;

  Station *playing;
}

@property (assign) Station *playing;

- (void) afterStationsLoaded;
- (void) playStation: (Station*) station;
- (IBAction)playpause: (id) sender;
- (IBAction)next: (id) sender;
- (IBAction)like: (id) sender;
- (IBAction)dislike: (id) sender;
- (IBAction)tired: (id) sender;

@end
