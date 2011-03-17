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

  if ([songs count] > 0 && shouldPlaySongOnFetch) {
    shouldPlaySongOnFetch = NO;
    [self play];
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

  playing = [songs objectAtIndex:0];
  [songs removeObjectAtIndex:0];

  stream = [[AudioStreamer alloc] initWithURL: [NSURL URLWithString: playing.url]];
  [stream start];

  NSNotification *notification =
    [NSNotification
      notificationWithName: @"song.playing"
      object:self];
  [[NSNotificationCenter defaultCenter]
    postNotification:notification];

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
}

@end
