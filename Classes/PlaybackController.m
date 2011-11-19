#import "AppleMediaKeyController.h"
#import "PlaybackController.h"
#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "Scrobbler.h"
#import "Growler.h"

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

  int saved = [[NSUserDefaults standardUserDefaults] integerForKey:@"hermes.volume"];
  if (saved == 0) {
    saved = 100;
  }
  [self setIntVolume:saved];

  for (Station *station in [[self pandora] stations]) {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(songPlayed:)
     name:@"song.playing"
     object:station];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(songsLoaded:)
     name:@"songs.loaded"
     object:station];
  }
}

- (void) songRated: (NSNotification*) not {
  [self hideSpinner];
}

- (void) songTired: (NSNotification*) not {
  [self hideSpinner];
}

- (void) noSongs: (NSNotification*) not {
  if ([playing playing] == nil) {
    [[NSApp delegate] setCurrentView:noSongsView];
  }
}

- (void) imageLoaded: (NSNotification*) not {
  if ([not object] != loader) {
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
    [Growler growl:[playing playing] withImage:growlImage];
  }

  [[art animator] setImage:image];
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
  if (dur > 30 && (prog * 2 > dur || prog > 4 * 60) && !scrobbleSent) {
    scrobbleSent = YES;
    [Scrobbler scrobble:[playing playing]];
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
      [Growler growl:[playing playing] withImage:[art image]];
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

  if ([[song rating] isEqualTo: @"1"]) {
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
    [Growler growl:[playing playing] withImage:[art image]];
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

  if ([[self pandora] rateSong: playingSong : @"1"]) {
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

  if ([[self pandora] rateSong: playingSong : @"0"]) {
    /* Remaining songs in the queue are probably related to this one. If we
     * dislike this one, remove all related songs to grab another 4 */
    [[[self playing] songs] removeAllObjects];
    [self next:sender];
  } else {
    NSLog(@"Couldn't rate song?!");
  }

}

/* We are tired o fthe currently playing song, play another */
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
