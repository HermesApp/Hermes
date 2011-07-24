#import "AppleMediaKeyController.h"
#import "PlaybackController.h"
#import "HermesAppDelegate.h"
#import "Scrobbler.h"

@implementation PlaybackController

@synthesize playing;

- (id) init {
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
    selector:@selector(noSongs:)
    name:@"hermes.no-songs"
    object:nil];

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

- (void) showSpinner {
  [songLoadingProgress setHidden:NO];
  [songLoadingProgress startAnimation:nil];
}

- (void) hideSpinner {
  [songLoadingProgress setHidden:YES];
  [songLoadingProgress stopAnimation:nil];
}

- (void) afterStationsLoaded {
  [[NSNotificationCenter defaultCenter]
    removeObserver:self
    name:@"song.playing"
    object:nil];

  double saved = [[NSUserDefaults standardUserDefaults] doubleForKey:@"hermes.volume"];
  if (saved == 0) {
    saved = 1.0;
  }
  [volume setDoubleValue:saved];

  for (Station *station in [[self pandora] stations]) {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(songPlayed:)
     name:@"song.playing"
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
  [[NSApp delegate] setCurrentView:noSongsView];
}

- (void) imageLoaded: (NSNotification*) not {
  NSImage *image = [[NSImage alloc] initWithData: [loader data]];

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
  } else {
    [image autorelease];
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
    [[playing stream] setVolume:[volume doubleValue]];
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
    NSLogd(@"No song to play!?");
    return;
  }

  if ([song art] == nil || [[song art] isEqual: @""]) {
    [art setImage: [NSImage imageNamed:@"missing-album"]];
  } else {
    [artLoading startAnimation:nil];
    [artLoading setHidden:NO];
    [art setImage:nil];
    [loader loadImageURL:[song art]];
  }

  [[NSApp delegate] setCurrentView:playbackView];

  [songLabel setStringValue: [song title]];
  [artistLabel setStringValue: [song artist]];
  [albumLabel setStringValue:[song album]];
  [playbackProgress setDoubleValue: 0];
  [progressLabel setStringValue: @"0:00/0:00"];
  scrobbleSent = NO;

  if ([song.rating isEqualTo: @"1"]) {
    [like setEnabled:NO];
  } else {
    [like setEnabled:YES];
  }

  [self hideSpinner];
}

/* Plays a new station */
- (void) playStation: (Station*) station {
  if (playing == station) {
    return;
  }

  [playing stop];
  [[NSApp delegate] setCurrentView:playbackView];
  [self showSpinner];
  [toolbar setVisible:YES];

  if (station == nil) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
  } else {
    [[NSUserDefaults standardUserDefaults]
      setObject:[station stationId]
      forKey:LAST_STATION_KEY];
  }

  playing = station;
  [playing play];
}

/* Toggle between playing and pausing */
- (IBAction)playpause: (id) sender {
//  if (![[self pandora] authenticated]) {
//    return;
//  }

  if ([[playing stream] isPlaying]) {
    [playing pause];
  } else {
    [playing play];
  }
}

/* Stop this song and go to the next */
- (IBAction)next: (id) sender {
//  if (![[self pandora] authenticated]) {
//    return;
//  }

  [art setImage:nil];
  [self showSpinner];

  [playing next];
}

/* Like button was hit */
- (IBAction)like: (id) sender {
  Song *playingSong = [playing playing];
  if (/*![[self pandora] authenticated] || */playingSong == nil) {
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
  if (/*![[self pandora] authenticated] || */playingSong == nil) {
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
  if (/*![[self pandora] authenticated] || */
      playing == nil || [playing playing] == nil) {
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

- (IBAction) volumeChanged: (id) sender {
  if (playing && [playing stream]) {
    [[playing stream] setVolume: [volume doubleValue]];
    [[NSUserDefaults standardUserDefaults]
      setDouble:[volume doubleValue]
      forKey:@"hermes.volume"];
  }
}

@end
