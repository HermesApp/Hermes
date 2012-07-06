/**
 * @file PlaybackController.m
 * @brief Implementation of the playback interface for playing/pausing
 *        songs
 *
 * Handles all information regarding playing a station, setting ratings for
 * songs, and listening for notifications. Deals with all user input related
 * to these actions as well
 */

#import <AudioStreamer/AudioStreamer.h>
#import <SPMediaKeyTap/SPMediaKeyTap.h>

#import "Growler.h"
#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "ImageLoader.h"
#import "PlaybackController.h"
#import "Scrobbler.h"
#import "StationsController.h"

BOOL playOnStart = YES;

@implementation PlaybackController

@synthesize playing;

+ (void) setPlayOnStart: (BOOL)play {
  playOnStart = play;
}

+ (BOOL) playOnStart {
  return playOnStart;
}

- (id) init {
  if (!(self = [super init])) {
    return self;
  }
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  progressUpdateTimer = nil;

  [center addObserver:self
             selector:@selector(windowClosing)
                 name:NSWindowWillCloseNotification
               object:[[NSApp delegate] window]];

  [center addObserver:self
             selector:@selector(windowOpening)
                 name:NSWindowDidBecomeKeyNotification
               object:[[NSApp delegate] window]];
  [self windowOpening];

  [center
    addObserver:self
    selector:@selector(hideSpinner)
    name:@"hermes.song-rated"
    object:[[NSApp delegate] pandora]];

  [center
    addObserver:self
    selector:@selector(hideSpinner)
    name:@"hermes.song-tired"
    object:[[NSApp delegate] pandora]];

  [center
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:nil];

  [center
     addObserver:self
     selector:@selector(songPlayed:)
     name:@"song.playing"
     object:nil];
  return self;
}

/* Don't run the timer when the application is closed */
- (void) windowClosing {
  [progressUpdateTimer invalidate];
  progressUpdateTimer = nil;
}

- (void) windowOpening {
  if (progressUpdateTimer != nil) return;
  progressUpdateTimer = [NSTimer
    scheduledTimerWithTimeInterval:.3
    target:self
    selector:@selector(updateProgress:)
    userInfo:nil
    repeats:YES];
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
      [self next:nil];
      return;

    case NX_KEYTYPE_REWIND:
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
  [toolbar setVisible:NO];
  if (playing) {
    [playing stop];
    [[ImageLoader loader] cancel:[[playing playing] art]];
  }
  playing = nil;
  lastImgSrc = nil;
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

/* If not implemented, disabled toolbar items suddenly get re-enabled? */
- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  if (theItem != like) return YES;
  if (playing == nil || [playing playing] == nil) return YES;
  return [[[playing playing] nrating] intValue] == 0;
}

/* Called whenever the playing stream changes state */
- (void)playbackStateChanged: (NSNotification *)aNotification {
  if ([playing isPlaying]) {
    NSLogd(@"Stream playing now...");
    [playbackProgress startAnimation:nil];
    [playpause setImage:[NSImage imageNamed:@"pause"]];
  } else if ([playing isPaused]) {
    NSLogd(@"Stream paused now...");
    [playpause setImage:[NSImage imageNamed:@"play"]];
    [playbackProgress stopAnimation:nil];
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
    [SCROBBLER scrobble:[playing playing] state:FinalStatus];
  }
}

/*
 * Called whenever a song starts playing, updates all fields to reflect that the
 * song is playing
 */
- (void)songPlayed: (NSNotification *)aNotification {
  Song *song = [playing playing];
  assert(song != nil);

  /* Prevent a flicker by not loading the same image twice */
  if ([song art] != lastImgSrc) {
    if ([song art] == nil || [[song art] isEqual: @""]) {
      [art setImage: [NSImage imageNamed:@"missing-album"]];
      [GROWLER growl:[playing playing] withImage:[art image] isNew:YES];
      [artLoading setHidden:YES];
      [artLoading stopAnimation:nil];
    } else {
      [artLoading startAnimation:nil];
      [artLoading setHidden:NO];
      [art setImage:nil];
      lastImgSrc = [song art];
      [[ImageLoader loader] loadImageURL:lastImgSrc
                                callback:^(NSData *data) {
        NSImage *image, *growlImage;
        if (data == nil) {
          image = [NSImage imageNamed:@"missing-album"];
          growlImage = [NSApp applicationIconImage];
        } else {
          image = growlImage = [[NSImage alloc] initWithData:data];
        }

        if (![playing isPaused]) {
          [GROWLER growl:[playing playing] withImage:growlImage isNew:YES];
        }
        [art setImage:image];
        [artLoading setHidden:YES];
        [artLoading stopAnimation:nil];
      }];
    }
  } else {
    NSLogd(@"Skipping loading image");
  }

  [[NSApp delegate] setCurrentView:playbackView];

  [songLabel setStringValue: [song title]];
  [artistLabel setStringValue: [song artist]];
  [albumLabel setStringValue:[song album]];
  [playbackProgress setDoubleValue: 0];
  [progressLabel setStringValue: @"0:00/0:00"];
  scrobbleSent = NO;

  if ([[song nrating] intValue] == 1) {
    [like setEnabled:NO];
  } else {
    [like setEnabled:YES];
  }

  [[[NSApp delegate] history] addSong:song];
  [self hideSpinner];
}

/* Plays a new station */
- (void) playStation: (Station*) station {
  if ([playing stationId] == [station stationId]) {
    return;
  }

  [playing stop];
  [[ImageLoader loader] cancel:[[playing playing] art]];
  [[NSApp delegate] setCurrentView:playbackView];
  [toolbar setVisible:YES];

  if (station == nil) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
  } else {
    [[NSUserDefaults standardUserDefaults] setObject:[station stationId]
                                              forKey:LAST_STATION_KEY];
  }

  playing = station;
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
    [GROWLER growl:[playing playing] withImage:[art image] isNew:NO];
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
  if ([playing playing] != nil) {
    [[ImageLoader loader] cancel:[[playing playing] art]];
  }

  [playing next];
}

/* Like button was hit */
- (IBAction)like: (id) sender {
  Song *playingSong = [playing playing];
  if (playingSong == nil) {
    return;
  }

  [self showSpinner];

  [[self pandora] rateSong:playingSong as:YES];
  [like setEnabled:NO];
}

/* Dislike button was hit */
- (IBAction)dislike: (id) sender {
  Song *playingSong = [playing playing];
  if (playingSong == nil) {
    return;
  }

  [self showSpinner];

  [[self pandora] rateSong:playingSong as:NO];
  /* Remaining songs in the queue are probably related to this one. If we
     dislike this one, remove all related songs to grab another set */
  [playing clearSongList];
  [self next:sender];
}

/* We are tired of the currently playing song, play another */
- (IBAction)tired: (id) sender {
  if (playing == nil || [playing playing] == nil) {
    return;
  }

  [[self pandora] tiredOfSong:[playing playing]];
  [self next:sender];
}

/* Load more songs manually */
- (IBAction)loadMore: (id)sender {
  [self showSpinner];
  [[NSApp delegate] setCurrentView:playbackView];

  if ([playing playing] != nil) {
    [playing retry:NO];
  } else {
    [playing play];
  }
}

/* Go to the song URL */
- (IBAction)songURL: (id) sender {
  if ([playing playing] == nil) {
    return;
  }

  NSURL *url = [NSURL URLWithString:[[playing playing] titleUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

/* Go to the artist URL */
- (IBAction)artistURL: (id) sender {
  if ([playing playing] == nil) {
    return;
  }

  NSURL *url = [NSURL URLWithString:[[playing playing] artistUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

/* Go to the album URL */
- (IBAction)albumURL: (id) sender {
  if ([playing playing] == nil) {
    return;
  }

  NSURL *url = [NSURL URLWithString:[[playing playing] albumUrl]];
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

- (IBAction) volumeChanged: (id) sender {
  if (playing && [playing isPlaying]) {
    [self setIntVolume:[volume intValue]];
  }
}

@end
