#import <Cocoa/Cocoa.h>

#import "Pandora/Station.h"
#import "Scrobbler.h"

@class Song;

@interface PlaybackController : NSObject {
  IBOutlet NSProgressIndicator *songLoadingProgress;

  IBOutlet NSView *playbackView;

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
  IBOutlet NSToolbarItem *dislike;
  IBOutlet NSToolbarItem *playpause;
  IBOutlet NSSlider *volume;
  IBOutlet NSToolbar *toolbar;

  NSTimer *progressUpdateTimer;
  BOOL scrobbleSent;
  NSString *lastImgSrc;
  NSData *lastImg;
}

@property (readonly) Station *playing;
@property BOOL pausedByScreensaver;

+ (void) setPlayOnStart: (BOOL)play;
+ (BOOL) playOnStart;

//- (void) applicationOpened;

- (void) reset;
- (void) playStation: (Station*) station;
- (BOOL) saveState;
- (void) show;
- (void) prepareFirst;

- (BOOL) play;
- (BOOL) pause;
- (void) setIntVolume: (int) volume;
- (int) getIntVolume;
- (void) pauseOnScreensaverStart: (NSNotification *) aNotification;
- (void) playOnScreensaverStop: (NSNotification *) aNotification;

- (void) rate:(Song *)song as:(BOOL)liked;

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
- (IBAction)increaseVolume:(id)sender;
- (IBAction)decreaseVolume:(id)sender;

@end
