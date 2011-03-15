//
//  Station.m
//  Pithos
//
//  Created by Alex Crichton on 3/12/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "Station.h"

@implementation Station

@synthesize station_id, name, songs, radio, stream, playing;

- (id) init {
  songs = [[NSMutableArray alloc] init];
  return self;
}

- (void) fetchMoreSongs {
  NSArray *more = [radio getFragment: station_id];

  if (more != nil) {
    [songs addObjectsFromArray: more];
    [more release];
  }
}

- (void) fetchSongsIfNecessary {
  if ([songs count] == 0) {
    [self fetchMoreSongs];

    if ([songs count] == 0) {
      NSLog(@"No songs!");
    }
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

  [self fetchSongsIfNecessary];

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
  if (!stream) {
    return;
  }

  [stream stop];
  [stream release];
  stream = nil;
}

@end
