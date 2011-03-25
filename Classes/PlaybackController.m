//
//  PlaybackController.m
//  Hermes
//
//  Created by Alex Crichton on 3/15/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "PlaybackController.h"
#import "HermesAppDelegate.h"

@implementation PlaybackController

@synthesize playing;

- (id) init {
  progressUpdateTimer = [NSTimer
    scheduledTimerWithTimeInterval:.3
    target:self
    selector:@selector(updateProgress:)
    userInfo:nil
    repeats:YES];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(songRated:)
    name:@"hermes.song-rated"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(songTired:)
    name:@"hermes.song-tired"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(noSongs:)
    name:@"hermes.no-songs"
    object:nil];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(loggedOut:)
    name:@"hermes.logged-out"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(afterStationsLoaded)
    name:@"hermes.stations"
    object:[[NSApp delegate] pandora]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:nil];

  loader = [[ImageLoader alloc] init];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(imageLoaded:)
    name:@"image-loaded"
    object:loader];

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
  [self hideSpinner];
  [sorryLabel setHidden:NO];
  [loadMore setHidden:NO];
}

- (void) hideAllPlaybackItems {
  [sorryLabel setHidden:YES];
  [loadMore setHidden:YES];
  [art setHidden:YES];
  [songLabel setHidden:YES];
  [songURL setHidden:YES];
  [artistLabel setHidden:YES];
  [artistURL setHidden:YES];
  [albumLabel setHidden:YES];
  [albumURL setHidden:YES];
  [playbackProgress setHidden:YES];
  [progressLabel setHidden:YES];
  [volup setHidden:YES];
  [voldown setHidden:YES];
  [volume setHidden:YES];

  [artLoading setHidden:YES];
  [artLoading stopAnimation:nil];

  [self hideSpinner];
}

- (void) loggedOut: (NSNotification*) not {
  [playing stop];
  playing = nil;

  [self hideAllPlaybackItems];
  [toolbar setVisible:NO];
}

- (void) imageLoaded: (NSNotification*) not {
  NSImage *image = [[NSImage alloc] initWithData: [loader data]];

  if (image == nil) {
    // Try the second art if this was just the first art
    NSString *prev = [loader loadedURL];
    NSString *orig = [[playing playing] art];
    NSString *nxt  = [[playing playing] otherArt];
    if ([prev isEqual:orig] && nxt != nil) {
      [loader loadImageURL:nxt];
      NSLog(@"Failed retrieving: %@, now trying: %@", orig, nxt);
      return;
    }

    image = [NSImage imageNamed:@"missing-album"];
  } else {
    [image autorelease];
  }

  [art setHidden:NO];
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
    NSLog(@"error registered in stream");
  } else if ([streamer isPlaying]) {
    [[playing stream] setVolume:[volume doubleValue]];
    [playpause setImage:[NSImage imageNamed:@"pause"]];
  } else if ([streamer isPaused]) {
    [playpause setImage:[NSImage imageNamed:@"play"]];
  } else if ([streamer isIdle]) {
    /* The currently playing song finished playing */
    [self next:nil];
  }
}

/* Re-draws the timer counting up the time of the played song */
- (void)updateProgress: (NSTimer *)updatedTimer {
  if (playing == nil || [playing stream] == nil) {
    return;
  }

  AudioStreamer *streamer = [playing stream];

  int prog = streamer.progress;
  int dur = streamer.duration;

  if (dur > 0) {
    [progressLabel setStringValue:
     [NSString stringWithFormat:@"%d:%02d/%d:%02d",
      prog / 60, prog % 60, dur / 60, dur % 60]];
    [playbackProgress setDoubleValue:100 * prog / dur];
  } else {
    //      [progress setEnabled:NO];
  }
}

/*
 * Called whenever a song starts playing, updates all fields to reflect that the song is
 * playing
 */
- (void)songPlayed: (NSNotification *)aNotification {
  Song *song = [playing playing];

  if (song == nil) {
    NSLog(@"No song to play!?");
    return;
  }

  if ([song art] == nil || [[song art] isEqual: @""]) {
    [art setImage: [NSImage imageNamed:@"missing-album"]];
    [art setHidden:NO];
  } else {
    [artLoading setHidden:NO];
    [artLoading startAnimation:nil];
    [art setHidden:YES];
    [loader loadImageURL:[song art]];
  }

  if ([artistLabel isHidden]) {
    [artistLabel setHidden:NO];
    [artistURL setHidden:NO];
    [songLabel setHidden:NO];
    [songURL setHidden:NO];
    [albumLabel setHidden:NO];
    [albumURL setHidden:NO];
    [playbackProgress setHidden:NO];
    [progressLabel setHidden:NO];
    [volup setHidden:NO];
    [voldown setHidden:NO];
    [volume setHidden:NO];
  }

  if (![loadMore isHidden]) {
    [loadMore setHidden:YES];
    [sorryLabel setHidden:YES];
  }

  [songLabel setStringValue: [song title]];
  [artistLabel setStringValue: [song artist]];
  [albumLabel setStringValue:[song album]];
  [playbackProgress setDoubleValue: 0];
  [progressLabel setStringValue: @"0:00/0:00"];

  if ([song.rating isEqualTo: @"1"]) {
    [like setEnabled:NO];
  } else {
    [like setEnabled:YES];
  }

  [self hideSpinner];
}

/* Plays a new station */
- (void) playStation: (Station*) station {
  if (![[self pandora] authenticated] || playing == station) {
    return;
  }

  if (playing != nil) {
    [art setHidden:YES];
    [self hideAllPlaybackItems];
    [playing stop];
  }

  [self showSpinner];
  [toolbar setVisible:YES];

  [[NSUserDefaults standardUserDefaults]
    setObject:[station stationId]
    forKey:LAST_STATION_KEY];

  playing = station;
  [playing play];
}

/* Toggle between playing and pausing */
- (IBAction)playpause: (id) sender {
  if (![[self pandora] authenticated]) {
    return;
  }

  if ([[playing stream] isPlaying]) {
    [playing pause];
  } else {
    [playing play];
  }
}

/* Stop this song and go to the next */
- (IBAction)next: (id) sender {
  if (![[self pandora] authenticated]) {
    return;
  }

  [art setHidden:YES];
  [self showSpinner];

  [playing next];
}

/* Like button was hit */
- (IBAction)like: (id) sender {
  Song *playingSong = [playing playing];
  if (![[self pandora] authenticated] || playingSong == nil) {
    return;
  }

  [self showSpinner];

  if ([[self pandora] rateSong: playingSong : @"1"]) {
    [like setEnabled:NO];
    [dislike setEnabled:YES];
  } else {
    NSLog(@"Couldn't rate song?!");
  }

}

/* Dislike button was hit */
- (IBAction)dislike: (id) sender {
  Song *playingSong = [playing playing];
  if (![[self pandora] authenticated] || playingSong == nil) {
    return;
  }

  [self showSpinner];

  if ([[self pandora] rateSong: playingSong : @"0"]) {
    [self next:sender];
  } else {
    NSLog(@"Couldn't rate song?!");
  }

}

/* We are tired o fthe currently playing song, play another */
- (IBAction)tired: (id) sender {
  if (![[self pandora] authenticated] ||
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
