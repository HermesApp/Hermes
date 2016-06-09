#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "Pandora/Station.h"
#import "Integration/Scrobbler.h"

@class Song;

@interface PlaybackController : NSObject <QLPreviewPanelDataSource, QLPreviewPanelDelegate, QLPreviewItem> {
  IBOutlet NSProgressIndicator *songLoadingProgress;

  IBOutlet NSView *playbackView;

  // Song view items
  IBOutlet NSTextField *songLabel;
  IBOutlet NSTextField *artistLabel;
  IBOutlet NSTextField *albumLabel;
  IBOutlet NSTextField *progressLabel;
  IBOutlet NSButton *art;
  IBOutlet NSSlider *playbackProgress;
  IBOutlet NSProgressIndicator *artLoading;

  // Playback related items
  IBOutlet NSToolbarItem *like;
  IBOutlet NSToolbarItem *dislike;
  IBOutlet NSToolbarItem *playpause;
  IBOutlet NSToolbarItem *nextSong;
  IBOutlet NSToolbarItem *tiredOfSong;
  IBOutlet NSSlider *volume;
  IBOutlet NSToolbar *toolbar;

  NSTimer *progressUpdateTimer;
  BOOL scrobbleSent;
  NSString *lastImgSrc;
  NSData *lastImg;
}

@property (readonly) Station *playing;
@property BOOL pausedByScreensaver;
@property BOOL pausedByScreenLock;

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
- (void) pauseOnScreenLock: (NSNotification *) aNotification;
- (void) playOnScreenUnlock: (NSNotification *) aNotification;

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
- (IBAction)quickLookArt:(id)sender;

@end
