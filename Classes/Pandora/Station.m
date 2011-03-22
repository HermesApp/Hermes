//
//  Station.m
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Station.h"

@implementation Station

@synthesize stationId, name, songs, radio, stream, playing;

- (id) init {
  [self setSongs:[NSMutableArray arrayWithCapacity:10]];

  /* Watch for error notifications */
  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:nil];

  return self;
}

- (void) stopObserving {
  if (radio != nil) {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:nil
     object:radio];
  }
}

- (void) dealloc {
  [self stop];
  [self stopObserving];

  [[NSNotificationCenter defaultCenter]
    removeObserver:self
    name:ASStatusChangedNotification
    object:nil];

  while ([songs count] > 0) {
    Song *s = [songs objectAtIndex:0];
    [songs removeObjectAtIndex:0];
    [s release];
  }

  [songs release];
  [stationId release];
  [name release];
  [super dealloc];
}

- (BOOL) isEqual:(id)object {
  return [stationId isEqual:[object stationId]];
}

- (void) setRadio:(Pandora *)pandora {
  [self stopObserving];
  radio = pandora;

  NSString *n = [NSString stringWithFormat:@"hermes.fragment-fetched.%@",
      stationId];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(songsLoaded:)
    name:n
    object:pandora];
}

- (void) songsLoaded: (NSNotification*)not {
  NSArray *more = [[not userInfo] objectForKey:@"songs"];

  if (more != nil) {
    [songs addObjectsFromArray: more];
  }

  if ([songs count] > 0) {
    if (shouldPlaySongOnFetch) {
      shouldPlaySongOnFetch = NO;
      [self play];
    }
  } else {
    [[NSNotificationCenter defaultCenter]
      postNotificationName:@"hermes.no-songs" object:self];
  }
}

- (void) fetchMoreSongs {
  [radio getFragment: stationId];
}

- (void) fetchSongsIfNecessary {
  if ([songs count] <= 1) {
    [self fetchMoreSongs];
  }
}

- (void) setAudioStream {
  NSURL *url = [NSURL URLWithString:[playing url]];
  AudioStreamer *s = [[AudioStreamer alloc] initWithURL: url];
  [s autorelease];
  [self setStream:s];
}

- (void)playbackStateChanged: (NSNotification *)aNotification {
  if ([stream errorCode] != 0) {
    /* Try a few times to re-initialize the stream just in case it was a fluke
     * which caused the stream to fail */
    if (tries <= 5) {
      NSLog(@"Error on playback stream! Retrying...");
      [self retry];
      tries++;
    } else {
      /* Well looks like we can't do anything, let the UI know that it needs
       * to ask the user about what's going on */
      [[NSNotificationCenter defaultCenter]
        postNotificationName:@"hermes.song-error" object:self];
    }
  }
}

- (void) retry {
  double progress = [stream progress];

  [self setAudioStream];
  [stream start];

  /* The AudioStreamer class takes a bit to get a bitrate and a file length,
   * so calling seekToTime won't work right here. Instead, delay this operation
   * for just half a second */
  NSNumber *num = [NSNumber numberWithDouble:progress];
  [NSTimer scheduledTimerWithTimeInterval:0.5 target:self
      selector:@selector(seekToLastKnownTime:)
      userInfo:num repeats:NO];
}

- (void) seekToLastKnownTime: (NSTimer *)updatedTimer {
  NSNumber *num = [updatedTimer userInfo];
  [stream seekToTime:[num doubleValue]];
}

- (void) play {
  if (stream) {
    if ([stream isPlaying]) {
      return;
    } else if ([stream isPaused]) {
      [stream pause];
      return;
    }

    NSLog(@"Unknown state?!");
    return;
  }

  if ([songs count] == 0) {
    shouldPlaySongOnFetch = YES;
    [radio getFragment: stationId];
    return;
  }

  [self setPlaying:[songs objectAtIndex:0]];
  [songs removeObjectAtIndex:0];

  [self setAudioStream];
  tries = 0;

  [stream start];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:@"song.playing" object:self];

  [self fetchSongsIfNecessary];
}

- (void) pause {
  if (![stream isPaused]) {
    [stream pause];
  }
}

- (void) next {
  [self stop];
  [self play];
}

- (void) stop {
  if (!stream || !playing) {
    return;
  }

  [stream stop];
  [stream release];
  [playing release];
  stream = nil;
  playing = nil;
}

@end
