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
  IBOutlet NSButton *artistURL;
  IBOutlet NSTextField *songLabel;
  IBOutlet NSButton *songURL;
  IBOutlet NSTextField *progressLabel;
  IBOutlet NSProgressIndicator *playbackProgress;
  IBOutlet NSImageView *art;
  IBOutlet NSProgressIndicator *artLoading;
  IBOutlet NSButton *albumURL;
  IBOutlet NSTextField *albumLabel;

  NSTimer *progressUpdateTimer;
  ImageLoader *loader;

  // Liking/Disliking/Tired
  IBOutlet NSToolbarItem *like;
  IBOutlet NSToolbarItem *dislike;
  IBOutlet NSToolbarItem *tired;

  // Volume
  IBOutlet NSImageView *volup;
  IBOutlet NSImageView *voldown;
  IBOutlet NSSlider *volume;

  // Toolbar Items
  IBOutlet NSToolbarItem *playpause;
  IBOutlet NSToolbarItem *next;
  IBOutlet NSToolbar *toolbar;

  Station *playing;

  // Sorry, you're not pandora one and you loaded too many songs
  IBOutlet NSTextField *sorryLabel;
  IBOutlet NSButton *loadMore;

  BOOL scrobbleSent;
}

@property (assign) Station *playing;

- (void) playStation: (Station*) station;
- (IBAction)playpause: (id) sender;
- (IBAction)next: (id) sender;
- (IBAction)like: (id) sender;
- (IBAction)dislike: (id) sender;
- (IBAction)tired: (id) sender;
- (IBAction)loadMore: (id)sender;
- (IBAction)songURL: (id)sender;
- (IBAction)artistURL: (id)sender;
- (IBAction)albumURL: (id)sender;
- (IBAction)volumeChanged: (id)sender;

- (void) loggedOut:(NSNotification *)not;

@end
