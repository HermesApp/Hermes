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

- (void) imageLoaded: (NSNotification*) not {
  NSImage *image = [[NSImage alloc] initWithData: [loader data]];
  [[art animator] setImage:image];
}

/* If not implemented, disabled toolbar items suddenly get re-enabled? */
- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  return [theItem isEnabled];
}

/* Called whenever the playing stream changes state */
- (void)playbackStateChanged: (NSNotification *)aNotification {
  AudioStreamer *streamer = [playing stream];

  if ([streamer isPlaying]) {
    [playpause setImage:[NSImage imageNamed:@"pause.png"]];
  } else if ([streamer isPaused]) {
    [playpause setImage:[NSImage imageNamed:@"play.png"]];
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

  [[NSNotificationCenter defaultCenter]
    removeObserver:self
    name:ASStatusChangedNotification
    object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:[playing stream]];

  if ([song art] == nil || [[song art] isEqual: @""]) {
    [art setImage: [NSImage imageNamed:@"missing-album.png"]];
  } else {
    [loader loadImageURL:[song art]];
  }

  if ([art isHidden]) {
    [art setHidden:NO];
    [artistLabel setHidden:NO];
    [songLabel setHidden:NO];
    [playbackProgress setHidden:NO];
    [progressLabel setHidden:NO];
  }

  [songLabel setStringValue: [song title]];
  [artistLabel setStringValue: [song artist]];
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
  if (playing == station) {
    return;
  }

  [self showSpinner];

  if (playing == nil) {
    [toolbar setVisible:YES];
  } else {
    [art setHidden:YES];
    [playbackProgress setHidden:YES];
    [progressLabel setHidden:YES];
    [playing stop];
  }

  [[NSUserDefaults standardUserDefaults]
    setObject:[station stationId]
    forKey:LAST_STATION_KEY];

  playing = station;
  [playing play];
}

/* Toggle between playing and pausing */
- (IBAction)playpause: (id) sender {
  if ([[playing stream] isPlaying]) {
    [playing pause];
  } else {
    [playing play];
  }
}

/* Stop this song and go to the next */
- (IBAction)next: (id) sender {
  [art setHidden:YES];
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
    [dislike setEnabled:YES];
  } else {
    NSLog(@"Couldn't rate song?!");
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

@end
