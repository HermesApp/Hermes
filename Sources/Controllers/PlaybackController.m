/**
 * @file PlaybackController.m
 * @brief Implementation of the playback interface for playing/pausing
 *        songs
 *
 * Handles all information regarding playing a station, setting ratings for
 * songs, and listening for notifications. Deals with all user input related
 * to these actions as well
 */

#import <SPMediaKeyTap/SPMediaKeyTap.h>

#import "Integration/Growler.h"
#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "ImageLoader.h"
#import "PlaybackController.h"
#import "Integration/Scrobbler.h"
#import "StationsController.h"
#import "PreferencesController.h"
#import "Notifications.h"

BOOL playOnStart = YES;

@interface NSToolbarItem ()
- (void)_setAllPossibleLabelsToFit:(NSArray *)toolbarItemLabels;
@end

@implementation PlaybackController

@synthesize playing;

+ (void) setPlayOnStart: (BOOL)play {
  playOnStart = play;
}

+ (BOOL) playOnStart {
  return playOnStart;
}

- (void) awakeFromNib {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  NSWindow *window = [[NSApp delegate] window];
  [center addObserver:self
             selector:@selector(stopUpdatingProgress)
                 name:NSWindowWillCloseNotification
               object:window];
  [center addObserver:self
             selector:@selector(stopUpdatingProgress)
                 name:NSApplicationDidHideNotification
               object:NSApp];
  [center addObserver:self
             selector:@selector(startUpdatingProgress)
                 name:NSWindowDidBecomeMainNotification
               object:window];
  [center addObserver:self
             selector:@selector(startUpdatingProgress)
                 name:NSApplicationDidUnhideNotification
               object:NSApp];

  [center
    addObserver:self
    selector:@selector(showToolbar)
    name:PandoraDidAuthenticateNotification
    object:nil];

  [center
    addObserver:self
    selector:@selector(hideSpinner)
    name:PandoraDidRateSongNotification
    object:nil];

  [center
    addObserver:self
    selector:@selector(hideSpinner)
    name:PandoraDidDeleteFeedbackNotification
    object:nil];

  [center
    addObserver:self
    selector:@selector(hideSpinner)
    name:PandoraDidTireSongNotification
    object:nil];

  [center
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:nil];

  [center
     addObserver:self
     selector:@selector(songPlayed:)
     name:StationDidPlaySongNotification
     object:nil];

  CIFilter *volumeSliderFilter = [CIFilter filterWithName:@"CIPhotoEffectMono"];
  if (volumeSliderFilter != nil)
    [volume setContentFilters:@[volumeSliderFilter]];

  CIFilter *playbackProgressFilter = [CIFilter filterWithName:@"CIPhotoEffectMono"];
  if (playbackProgressFilter != nil)
    [playbackProgress setContentFilters:@[playbackProgressFilter]];
  
  // NSDistributedNotificationCenter is for interprocess communication.
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(pauseOnScreensaverStart:)
                                                          name:AppleScreensaverDidStartDistributedNotification
                                                        object:nil];
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(playOnScreensaverStop:)
                                                          name:AppleScreensaverDidStopDistributedNotification
                                                        object:nil];
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(pauseOnScreenLock:)
                                                          name:AppleScreenIsLockedDistributedNotification
                                                        object:nil];
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(playOnScreenUnlock:)
                                                          name:AppleScreenIsUnlockedDistributedNotification
                                                        object:nil];

  // This has been SPI forever, but will stop the toolbar icons from sliding around.
  if ([playpause respondsToSelector:@selector(_setAllPossibleLabelsToFit:)])
    [playpause _setAllPossibleLabelsToFit:@[@"Play", @"Pause"]];
  
  // prevent dragging the progress slider
  [playbackProgress setEnabled:NO];
}

- (void)showToolbar {
  toolbar.visible = YES;
}

/* Don't run the timer when playback is paused, the window is hidden, etc. */
- (void) stopUpdatingProgress {
  [progressUpdateTimer invalidate];
  progressUpdateTimer = nil;
}

- (void) startUpdatingProgress {
  if (progressUpdateTimer != nil) return;
  progressUpdateTimer = [NSTimer
    timerWithTimeInterval:1
    target:self
    selector:@selector(updateProgress:)
    userInfo:nil
    repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:progressUpdateTimer forMode:NSRunLoopCommonModes];
}

/* see https://github.com/nevyn/SPMediaKeyTap */
- (void) mediaKeyTap:(SPMediaKeyTap*)keyTap
      receivedMediaKeyEvent:(NSEvent*)event {
  assert([event type] == NSSystemDefined &&
         [event subtype] == SPSystemDefinedEventMediaKeys);

  int keyCode = (([event data1] & 0xFFFF0000) >> 16);
  int keyFlags = ([event data1] & 0x0000FFFF);
  int keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
  if (keyState != 1) return;

  switch (keyCode) {

    case NX_KEYTYPE_PLAY:
      [self playpause:nil];
      return;

    case NX_KEYTYPE_FAST:
    case NX_KEYTYPE_NEXT:
      [self next:nil];
      return;

    case NX_KEYTYPE_REWIND:
    case NX_KEYTYPE_PREVIOUS:
      [NSApp activateIgnoringOtherApps:NO];
      return;
  }
}

- (void) prepareFirst {
  int saved = [[NSUserDefaults standardUserDefaults]
                  integerForKey:@"hermes.volume"];
  if (saved == 0) {
    saved = 100;
  }
  [self setIntVolume:saved];
}

- (Pandora*) pandora {
  return [[NSApp delegate] pandora];
}

- (void) reset {
  [self playStation:nil];

  NSString *path = [[NSApp delegate] stateDirectory:@"station.savestate"];
  [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void) show {
  [[NSApp delegate] setCurrentView:playbackView];
}

- (void) showSpinner {
  [songLoadingProgress setHidden:NO];
  [songLoadingProgress startAnimation:nil];
}

- (void) hideSpinner {
  [songLoadingProgress setHidden:YES];
  [songLoadingProgress stopAnimation:nil];
}

- (BOOL) saveState {
  NSString *path = [[NSApp delegate] stateDirectory:@"station.savestate"];
  if (path == nil) {
    return NO;
  }

  return [NSKeyedArchiver archiveRootObject:[self playing] toFile:path];
}

/* Called whenever the playing stream changes state */
- (void)playbackStateChanged: (NSNotification *)aNotification {
  if ([playing isPlaying]) {
    NSLogd(@"Stream playing: %@", playing.playingSong);
    [playpause setImage:[NSImage imageNamed:@"pause"]];
    [playpause setLabel:@"Pause"];
    [self startUpdatingProgress];
  } else if ([playing isPaused]) {
    NSLogd(@"Stream paused.");
    [playpause setImage:[NSImage imageNamed:@"play"]];
    [playpause setLabel:@"Play"];
    [self stopUpdatingProgress];
  }
}

/* Re-draws the timer counting up the time of the played song */
- (void)updateProgress: (NSTimer *)updatedTimer {
  double prog, dur;

  if (![playing progress:&prog] || ![playing duration:&dur]) {
    [progressLabel setStringValue:@"-:--/-:--"];
    [playbackProgress setDoubleValue:0];
    return;
  }

  [progressLabel setStringValue:
    [NSString stringWithFormat:@"%d:%02d/%d:%02d",
    (int) (prog / 60), ((int) prog) % 60, (int) (dur / 60), ((int) dur) % 60]];
  [playbackProgress setDoubleValue:100 * prog / dur];

  /* See http://www.last.fm/api/scrobbling#when-is-a-scrobble-a-scrobble for
     figuring out when a track should be scrobbled */
  if (!scrobbleSent && dur > 30 && (prog * 2 > dur || prog > 4 * 60)) {
    scrobbleSent = YES;
    [SCROBBLER scrobble:[playing playingSong] state:FinalStatus];
  }
}

- (void)updateQuickLookPreviewWithArt:(BOOL)hasArt {
  [art setEnabled:hasArt];

  if (![QLPreviewPanel sharedPreviewPanelExists])
    return;

  QLPreviewPanel *previewPanel = [QLPreviewPanel sharedPreviewPanel];
  if (previewPanel.currentController != [NSApp delegate])
    return;

  if (hasArt)
    [previewPanel refreshCurrentPreviewItem];
  else
    [previewPanel reloadData];
}

/*
 * Called whenever a song starts playing, updates all fields to reflect that the
 * song is playing
 */
- (void)songPlayed: (NSNotification *)aNotification {
  Song *song = [playing playingSong];
  assert(song != nil);

  song.playDate = [NSDate date];

  /* Prevent a flicker by not loading the same image twice */
  if ([song art] != lastImgSrc) {
    if ([song art] == nil || [[song art] isEqual: @""]) {
      [art setImage: [NSImage imageNamed:@"missing-album"]];
      [GROWLER growl:song withImage:nil isNew:YES];
      [artLoading setHidden:YES];
      [artLoading stopAnimation:nil];
      [self updateQuickLookPreviewWithArt:NO];
    } else {
      [artLoading startAnimation:nil];
      [artLoading setHidden:NO];
      [art setImage:nil];
      lastImgSrc = [song art];
      lastImg = nil;
      [[ImageLoader loader] loadImageURL:lastImgSrc
                                callback:^(NSData *data) {
        NSImage *image = nil;
        lastImg = data;
        if (data == nil) {
          image = [NSImage imageNamed:@"missing-album"];
        } else {
          image = [[NSImage alloc] initWithData:data];
        }

        if (![playing isPaused]) {
          [GROWLER growl:song withImage:data isNew:YES];
        }
        [art setImage:image];
        [artLoading setHidden:YES];
        [artLoading stopAnimation:nil];
        [self updateQuickLookPreviewWithArt:data != nil];
      }];
    }
  } else {
    NSLogd(@"Skipping loading image");
  }

  [[NSApp delegate] setCurrentView:playbackView];

  [songLabel setStringValue: [song title]];
  [songLabel setToolTip:[song title]];
  [artistLabel setStringValue: [song artist]];
  [artistLabel setToolTip:[song artist]];
  [albumLabel setStringValue:[song album]];
  [albumLabel setToolTip:[song album]];
  [playbackProgress setDoubleValue: 0];
  if ([NSFont respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
    [progressLabel setFont:[NSFont monospacedDigitSystemFontOfSize:[[progressLabel font] pointSize] weight:NSFontWeightRegular]];
  }
  [progressLabel setStringValue: @"0:00/0:00"];
  scrobbleSent = NO;

  if ([[song nrating] intValue] == 1) {
    [toolbar setSelectedItemIdentifier:[like itemIdentifier]];
  } else {
    [toolbar setSelectedItemIdentifier:nil];
  }

  [[[NSApp delegate] history] addSong:song];
  [self hideSpinner];
}

/* Plays a new station, or nil to play no station (e.g., if station deleted) */
- (void) playStation: (Station*) station {
  if ([playing stationId] == [station stationId]) {
    return;
  }

  if (playing) {
    [playing stop];
    [[ImageLoader loader] cancel:[[playing playingSong] art]];
  }

  playing = station;

  if (station == nil) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
    lastImgSrc = nil;
    return;
  }

  [[NSUserDefaults standardUserDefaults] setObject:[station stationId]
                                            forKey:LAST_STATION_KEY];
  
  [[NSApp delegate] showLoader];

  if (playOnStart) {
    [station play];
  } else {
    playOnStart = YES;
  }
  [playing setVolume:[volume intValue]/100.0];
}

- (BOOL) play {
  if ([playing isPlaying]) {
    return NO;
  } else {
    [playing play];
    [GROWLER growl:[playing playingSong] withImage:lastImg isNew:NO];
    return YES;
  }
}

- (BOOL) pause {
  if ([playing isPlaying]) {
    [playing pause];
    return YES;
  } else {
    return NO;
  }
}

- (void) rate:(Song *)song as:(BOOL)liked {
  if (!song || [[song station] shared]) return;
  int rating = liked ? 1 : -1;

  // Should we delete the rating?
  if ([[song nrating] intValue] == rating) {
    rating = 0;
  }

  [self showSpinner];
  BOOL songIsPlaying = [playing playingSong] == song;

  if (rating == -1) {
    [[self pandora] rateSong:song as:NO];
    if (songIsPlaying) {
      [self next:nil];
    }
  }
  else if (rating == 0) {
    [[self pandora] deleteRating:song];
    if (songIsPlaying) {
      [toolbar setSelectedItemIdentifier:nil];
    }
  }
  else if (rating == 1) {
    [[self pandora] rateSong:song as:YES];
    if (songIsPlaying) {
      [toolbar setSelectedItemIdentifier:[like itemIdentifier]];
    }
  }

  if ([[[NSApp delegate] history] selectedItem] == song) {
    [[[NSApp delegate] history] updateUI];
  }
}

/* Toggle between playing and pausing */
- (IBAction)playpause: (id) sender {
  if ([playing isPaused]) {
    [self play];
  } else {
    [self pause];
  }
}

/* Stop this song and go to the next */
- (IBAction)next: (id) sender {
  [art setImage:nil];
  [self showSpinner];
  if ([playing playingSong] != nil) {
    [[ImageLoader loader] cancel:[[playing playingSong] art]];
  }

  [playing next];
}

/* Like button was hit */
- (IBAction)like: (id) sender {
  Song *song = [playing playingSong];
  if (!song) return;
  [self rate:song as:YES];
}

/* Dislike button was hit */
- (IBAction)dislike: (id) sender {
  Song *song = [playing playingSong];
  if (!song) return;

  /* Remaining songs in the queue are probably related to this one. If we
     dislike this one, remove all related songs to grab another set */
  [playing clearSongList];
  [self rate:song as:NO];
}

/* We are tired of the currently playing song, play another */
- (IBAction)tired: (id) sender {
  if (playing == nil || [playing playingSong] == nil) {
    return;
  }

  [[self pandora] tiredOfSong:[playing playingSong]];
  [self next:sender];
}

/* Load more songs manually */
- (IBAction)loadMore: (id)sender {
  [self showSpinner];
  [[NSApp delegate] setCurrentView:playbackView];

  if ([playing playingSong] != nil) {
    [playing retry];
  } else {
    [playing play];
  }
}

/* Go to the song URL */
- (IBAction)songURL: (id) sender {
  if ([playing playingSong] == nil) {
    return;
  }

  NSURL *url = [NSURL URLWithString:[[playing playingSong] titleUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

/* Go to the artist URL */
- (IBAction)artistURL: (id) sender {
  if ([playing playingSong] == nil) {
    return;
  }

  NSURL *url = [NSURL URLWithString:[[playing playingSong] artistUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

/* Go to the album URL */
- (IBAction)albumURL: (id) sender {
  if ([playing playingSong] == nil) {
    return;
  }

  NSURL *url = [NSURL URLWithString:[[playing playingSong] albumUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) setIntVolume: (int) vol {
  if (vol < 0) { vol = 0; }
  if (vol > 100) { vol = 100; }
  [volume setIntValue:vol];
  [playing setVolume:vol/100.0];
  [[NSUserDefaults standardUserDefaults] setInteger:vol
                                             forKey:@"hermes.volume"];
}

- (int) getIntVolume {
  return [volume intValue];
}

- (void) pauseOnScreensaverStart:(NSNotification *)aNotification {
  if (!PREF_KEY_BOOL(PAUSE_ON_SCREENSAVER_START)) {
    return;
  }
  
  if ([self pause]){
    self.pausedByScreensaver = YES;
  }
}

- (void) playOnScreensaverStop:(NSNotification *)aNotification {
  if (!PREF_KEY_BOOL(PLAY_ON_SCREENSAVER_STOP)) {
    return;
  }

  if (self.pausedByScreensaver) {
    [self play];
  }
  self.pausedByScreensaver = NO;
}

- (void) pauseOnScreenLock:(NSNotification *)aNotification {
  if (!PREF_KEY_BOOL(PAUSE_ON_SCREEN_LOCK)) {
    return;
  }
  
  if ([self pause]){
    self.pausedByScreenLock = YES;
  }
}

- (void) playOnScreenUnlock:(NSNotification *)aNotification {
  if (!PREF_KEY_BOOL(PLAY_ON_SCREEN_UNLOCK)) {
    return;
  }
  
  if (self.pausedByScreenLock) {
    [self play];
  }
  self.pausedByScreenLock = NO;
}

- (IBAction) volumeChanged: (id) sender {
  if (playing) {
    [self setIntVolume:[volume intValue]];
  }
}

- (IBAction)increaseVolume:(id)sender {
  [self setIntVolume:[self getIntVolume] + 5];
}

- (IBAction)decreaseVolume:(id)sender {
  [self setIntVolume:[self getIntVolume] - 5];
}

- (IBAction)quickLookArt:(id)sender {
  QLPreviewPanel *previewPanel = [QLPreviewPanel sharedPreviewPanel];
  if ([previewPanel isVisible])
    [previewPanel orderOut:nil];
  else
    [previewPanel makeKeyAndOrderFront:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  if (![[self pandora] isAuthenticated]) {
    return NO;
  }

  SEL action = [menuItem action];

  if (action == @selector(playpause:)) {
    [menuItem setTitle:[playing isPaused] ? @"Play" : @"Pause"];
  }

  if (action == @selector(like:) || action == @selector(dislike:)) {
    Song *song = [playing playingSong];
    if (song && ![playing shared]) {
      NSInteger rating = [[song nrating] integerValue];
      if (action == @selector(like:)) {
        [menuItem setState:rating == 1 ? NSOnState : NSOffState];
      } else {
        [menuItem setState:rating == -1 ? NSOnState : NSOffState];
      }
      return YES;
    } else {
      [menuItem setState:NSOffState];
      return NO;
    }
  }

  return YES;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
  if (![[self pandora] isAuthenticated]) {
    return NO;
  }

  if (toolbarItem == playpause || toolbarItem == nextSong || toolbarItem == tiredOfSong)
    return (playing != nil);

  if (toolbarItem == like || toolbarItem == dislike) {
    return [playing playingSong] && ![playing shared];
  }
  return YES;
}

#pragma mark QLPreviewPanelDataSource

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
  Song *song = [playing playingSong];
  if (song == nil)
    return 0;

  if ([song art] == nil || [[song art] isEqual: @""])
    return 0;

  return 1;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
  return self;
}

#pragma mark QLPreviewItem

- (NSURL *)previewItemURL {
  NSURL *artFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Hermes Album Art.tiff"]];
  [[[art image] TIFFRepresentation] writeToURL:artFileURL atomically:YES];

  return artFileURL;
}

- (NSString *)previewItemTitle {
  return [[playing playingSong] album];
}

#pragma mark QLPreviewPanelDelegate

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item {
  NSRect frame = [art frame];
  frame = [[[NSApp delegate] window] convertRectToScreen:frame];

  frame = NSInsetRect(frame, 1, 1); // image doesn't extend into the button border

  NSImage *image = [art image];
  NSSize imageSize = [image size]; // correct for aspect ratio
  if (imageSize.width > imageSize.height)
    frame = NSInsetRect(frame, 0, ((imageSize.width - imageSize.height) / imageSize.height) / 2. * frame.size.height);
  else if (imageSize.height > imageSize.width)
    frame = NSInsetRect(frame, ((imageSize.height - imageSize.width) / imageSize.width) / 2. * frame.size.width, 0);

  return frame;
}

- (NSImage *)previewPanel:(QLPreviewPanel *)panel transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(NSRect *)contentRect {

  return [art image];
}

@end
