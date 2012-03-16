#import <Cocoa/Cocoa.h>
#import "Station.h"
#import "ImageLoader.h"
#import "Scrobbler.h"

@interface PlaybackController : NSObject {
  IBOutlet NSProgressIndicator *songLoadingProgress;

  IBOutlet NSView *playbackView;
  IBOutlet NSView *noSongsView;

  // Song view items
  IBOutlet NSTextField *artistLabel;
  IBOutlet NSTextField *songLabel;
  IBOutlet NSTextField *progressLabel;
  IBOutlet NSProgressIndicator *playbackProgress;
  IBOutlet NSImageView *art;
  IBOutlet NSProgressIndicator *artLoading;
  IBOutlet NSTextField *albumLabel;

  // Playback related items
  IBOutlet NSToolbarItem *like;
  IBOutlet NSToolbarItem *playpause;
  IBOutlet NSSlider *volume;
  IBOutlet NSToolbar *toolbar;
  IBOutlet NSMenuItem *dockPlayPause;

  NSTimer *progressUpdateTimer;
  ImageLoader *loader;
  Station *playing;
  ScrobbleState scrobbleState;
  NSString *lastImgSrc;
}

@property (retain) Station *playing;

+ (void) setPlayOnStart: (BOOL)play;
+ (BOOL) playOnStart;

- (void) reset;
- (void) noSongs: (NSNotification*) notification;
- (void) playStation: (Station*) station;
- (BOOL) saveState;

- (BOOL) play;
- (BOOL) pause;
- (void) setIntVolume: (int) volume;
- (int) getIntVolume;
- (Song *) getCurrentSong;

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

@end
