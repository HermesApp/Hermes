/**
 * @file PlaybackController.m
 * @brief Implementation of the playback interface for playing/pausing
 *        songs
 *
 * Handles all information regarding playing a station, setting ratings for
 * songs, and listening for notifications. Deals with all user input related
 * to these actions as well
 */

#import "AppleMediaKeyController.h"
#import "Growler.h"
#import "HermesAppDelegate.h"
#import "HistoryController.h"
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

  progressUpdateTimer = [NSTimer
    scheduledTimerWithTimeInterval:.3
    target:self
    selector:@selector(updateProgress:)
    userInfo:nil
    repeats:YES];

  [center
    addObserver:self
    selector:@selector(songRated:)
    name:@"hermes.song-rated"
    object:[[NSApp delegate] pandora]];

  [center
    addObserver:self
    selector:@selector(songTired:)
    name:@"hermes.song-tired"
    object:[[NSApp delegate] pandora]];

  [center
    addObserver:self
    selector:@selector(afterStationsLoaded)
    name:@"hermes.stations"
    object:[[NSApp delegate] pandora]];

  [center
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:nil];

  loader = [[ImageLoader alloc] init];

  [center
    addObserver:self
    selector:@selector(imageLoaded:)
    name:@"image-loaded"
    object:loader];

  [center
    addObserver:self
    selector:@selector(playpause:)
    name:MediaKeyPlayPauseNotification
    object:nil];

  [center
    addObserver:NSApp
    selector:@selector(activateIgnoringOtherApps:)
    name:MediaKeyPreviousNotification
    object:nil];

  [center
    addObserver:self
    selector:@selector(next:)
    name:MediaKeyNextNotification
    object:nil];

  return self;
}

- (Pandora*) pandora {
  return [[NSApp delegate] pandora];
}

- (void) reset {
  [toolbar setVisible:NO];
  if (playing) {
    [playing stop];
  }
  [self setPlaying:nil];
  lastImgSrc = nil;
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"hermes.volume"];
  NSString *path = [[NSApp delegate] stateDirectory:@"station.savestate"];
  [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
  [[NSNotificationCenter defaultCenter]
   removeObserver:self
   name:@"song.playing"
   object:nil];
  [[NSNotificationCenter defaultCenter]
   removeObserver:self
   name:@"songs.loaded"
   object:nil];
}

- (void) enableAllToolbarItems {
  for (NSButton *b in [toolbar items]) {
    [b setEnabled:YES];
  }
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

- (void) afterStationsLoaded {
  [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:@"song.playing"
     object:nil];
  [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:@"songs.loaded"
     object:nil];

  int saved = [[NSUserDefaults standardUserDefaults]
                  integerForKey:@"hermes.volume"];
  if (saved == 0) {
    saved = 100;
  }
  [self setIntVolume:saved];

  [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(songPlayed:)
     name:@"song.playing"
     object:nil];
  [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(songsLoaded:)
     name:@"songs.loaded"
     object:nil];
}

- (void) songRated: (NSNotification*) not {
  Song *song = [[not userInfo] objectForKey:@"song"];
  if (song) {
    [Scrobbler setPreference:song loved:[[song nrating] intValue] == 1];
  }
  [self hideSpinner];
}

- (void) songTired: (NSNotification*) not {
  /* I'm actually not sure if I should send this as a dislike..
   * Could just mean "I've heard this 1000 times already!!!"
   * I still think it's a good idea to send the song info for
   * future utilization.
   *
  Song* song = [[not userInfo] objectForKey:@"song"];

  if (song) {
    [Scrobbler setPreference:song loved:NO];
  }
   */
  [self hideSpinner];
}

- (void) noSongs: (NSNotification*) not {
  if ([playing playing] == nil) {
    [[NSApp delegate] setCurrentView:noSongsView];
  }
}

- (void) imageLoaded: (NSNotification*) not {
  assert([not object] == loader);
  if (playing == nil || [playing playing] == nil) {
    return;
  }

  NSImage *image = [[NSImage alloc] initWithData: [loader data]];
  NSImage *growlImage = image;

  if (image == nil) {
    // Try the second art if this was just the first art
    NSString *prev = [loader loadedURL];
    NSString *orig = [[playing playing] art];
    NSString *nxt  = [orig stringByReplacingOccurrencesOfString:@"130W_130H"
                                                     withString:@"500W_500H"];

    if ([prev isEqual:orig] && nxt != nil) {
      [loader loadImageURL:nxt];
      NSLogd(@"Failed retrieving: %@, now trying: %@", orig, nxt);
      return;
    }

    image = [NSImage imageNamed:@"missing-album"];
    growlImage = [NSApp icon];
  }

  if (![playing isPaused]) {
    [Growler growl:[playing playing] withImage:growlImage isNew:YES];
  }

  [art setImage:image];
  [artLoading setHidden:YES];
  [artLoading stopAnimation:nil];
}

/* If not implemented, disabled toolbar items suddenly get re-enabled? */
- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  return [theItem isEnabled];
}

/* Called whenever the playing stream changes state */
- (void)playbackStateChanged: (NSNotification *)aNotification {
  AudioStreamer *streamer = [playing stream];

  if ([streamer errorCode] != 0) {
    /* Errors are handle elsewhere, we just need to make sure we take no
     * action here to muck up with whatever else is going on */
    NSLogd(@"error registered in stream");
  } else if ([streamer isPlaying]) {
    NSLogd(@"Stream playing now...");
    [[playing stream] setVolume:[volume intValue]/100.0];
    [playbackProgress startAnimation:nil];
    [playpause setImage:[NSImage imageNamed:@"pause"]];
  } else if ([streamer isPaused]) {
    NSLogd(@"Stream paused now...");
    [playpause setImage:[NSImage imageNamed:@"play"]];
    [playbackProgress stopAnimation:nil];
  } else if ([streamer isIdle]) {
    NSLogd(@"Stream idle, nexting...");
    /* The currently playing song finished playing */
    [self next:nil];
  } else {
    NSLogd(@"unknown state...");
  }
}

/* Re-draws the timer counting up the time of the played song */
- (void)updateProgress: (NSTimer *)updatedTimer {
  if (playing == nil || [playing stream] == nil || [playing isPaused]) {
    return;
  }

  AudioStreamer *streamer = [playing stream];

  double prog = [streamer progress];
  double dur = [streamer duration];

  /* The AudioStreamer class needs some time to figure out how long the song
     actually is. If the duration listed is less than or equal to 0, just give
     it some more time to figure this out */
  if (dur <= 0) {
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
    [Scrobbler scrobble:[playing playing] state:FinalStatus];
  }
}

/*
 * Called whenever a song starts playing, updates all fields to reflect that the song is
 * playing
 */
- (void)songPlayed: (NSNotification *)aNotification {
  Song *song = [playing playing];
  if (song == nil) {
    song = [[playing songs] objectAtIndex:0];
  }

  if (song == nil) {
    NSLogd(@"No song to play!?");
    NSLogd(@"%@",[NSThread callStackSymbols]);
    return;
  }

  /* Prevent a flicker by not loading the same image twice */
  if ([song art] != lastImgSrc) {
    if ([song art] == nil || [[song art] isEqual: @""]) {
      [art setImage: [NSImage imageNamed:@"missing-album"]];
      [Growler growl:[playing playing] withImage:[art image] isNew:YES];
    } else {
      [artLoading startAnimation:nil];
      [artLoading setHidden:NO];
      [art setImage:nil];
      lastImgSrc = [song art];
      [loader loadImageURL:lastImgSrc];
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

  [self enableAllToolbarItems];
  if ([[song nrating] intValue] == 1) {
    [like setEnabled:NO];
  } else {
    [like setEnabled:YES];
  }

  [[[NSApp delegate] history] addSong:song];
  [self hideSpinner];
}

- (void) songsLoaded: (NSNotification*) aNotification {
  if ([playing playing] == nil && [[playing songs] count] > 0) {
    [self songPlayed:nil];
  }
}

/* Plays a new station */
- (void) playStation: (Station*) station {
  if ([playing stationId] == [station stationId]) {
    return;
  }

  [playing stop];
  [[NSApp delegate] setCurrentView:playbackView];
  [toolbar setVisible:YES];

  if (station == nil) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
  } else {
    [[NSUserDefaults standardUserDefaults]
      setObject:[station stationId]
      forKey:LAST_STATION_KEY];
  }

  [self setPlaying:station];
  if (playOnStart) {
    [playing play];
  } else {
    NSString *saved_state = [[NSApp delegate] stateDirectory:@"station.savestate"];
    if (saved_state != nil) {
      Station *s = [NSKeyedUnarchiver unarchiveObjectWithFile:saved_state];
      if ([station isEqual:s]) {
        [station copyFrom:s];
      }
    }
    if ([station playing] != nil) {
      [self songPlayed:nil];
    } else if ([[station songs] count] > 0) {
      [self songPlayed:nil];
    } else {
      [station fetchMoreSongs];
    }
    playOnStart = true;
  }
}

- (BOOL) play {
  if ([[playing stream] isPlaying]) {
    return NO;
  } else {
    [playing play];
    [Growler growl:[playing playing] withImage:[art image] isNew:NO];
    return YES;
  }
}

- (BOOL) pause {
  if ([[playing stream] isPlaying]) {
    [playing pause];
    return YES;
  } else {
    return NO;
  }
}

/* Toggle between playing and pausing */
- (IBAction)playpause: (id) sender {
  if ([[playing stream] isPlaying]) {
    [self pause];
  } else {
    [self play];
  }
}

/* Stop this song and go to the next */
- (IBAction)next: (id) sender {
  [art setImage:nil];
  [self showSpinner];

  [playing next];
}

/* Like button was hit */
- (IBAction)like: (id) sender {
  Song *playingSong = [playing playing];
  if (playingSong == nil) {
    return;
  }

  [self showSpinner];

  if ([[self pandora] rateSong:playingSong as:YES]) {
    [like setEnabled:NO];
  } else {
    NSLogd(@"Couldn't rate song?!");
  }
}

/* Dislike button was hit */
- (IBAction)dislike: (id) sender {
  Song *playingSong = [playing playing];
  if (playingSong == nil) {
    return;
  }

  [self showSpinner];

  if ([[self pandora] rateSong:playingSong as:NO]) {
    /* Remaining songs in the queue are probably related to this one. If we
     * dislike this one, remove all related songs to grab another 4 */
    [[[self playing] songs] removeAllObjects];
    [self next:sender];
  } else {
    NSLog(@"Couldn't rate song?!");
  }
}

/* We are tired of the currently playing song, play another */
- (IBAction)tired: (id) sender {
  if (playing == nil || [playing playing] == nil) {
    return;
  }

  if ([[self pandora] tiredOfSong:[playing playing]]) {
    [self next:sender];
  } else {
    NSLog(@"Couldn't get tired of a song?!");
  }
}

/* Load more songs manually */
- (IBAction)loadMore: (id)sender {
  [self showSpinner];
  [[NSApp delegate] setCurrentView:playbackView];

  if ([playing playing] != nil) {
    [playing retry];
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
  [[playing stream] setVolume: vol/100.0];
  [[NSUserDefaults standardUserDefaults]
        setInteger:vol
            forKey:@"hermes.volume"];
}

- (int) getIntVolume {
  return [volume intValue];
}

- (IBAction) volumeChanged: (id) sender {
  NSLogd(@"Volume changed to: %d", [volume intValue]);
  if (playing && [playing stream]) {
    [self setIntVolume:[volume intValue]];
  }
}

@end
