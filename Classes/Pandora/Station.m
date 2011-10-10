#import "Station.h"

@implementation Station

@synthesize stationId, name, songs, stream, playing;

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

- (id) initWithCoder:(NSCoder *)aDecoder {
  if ((self = [self init])) {
    [self setStationId:[aDecoder decodeObjectForKey:@"stationId"]];
    [self setName:[aDecoder decodeObjectForKey:@"name"]];
    [self setPlaying:[aDecoder decodeObjectForKey:@"playing"]];
    lastKnownSeekTime = [aDecoder decodeFloatForKey:@"lastKnownSeekTime"];
    [songs addObjectsFromArray:[aDecoder decodeObjectForKey:@"songs"]];
    restored = YES;
  }
  return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:stationId forKey:@"stationId"];
  [aCoder encodeObject:name forKey:@"name"];
  [aCoder encodeObject:playing forKey:@"playing"];
  float seek = -1;
  if (playing) {
    seek = [stream progress];
  }
  [aCoder encodeFloat:seek forKey:@"lastKnownSeekTime"];
  [aCoder encodeObject:songs forKey:@"songs"];
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

  [songs removeAllObjects];
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

  if (shouldPlaySongOnFetch) {
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

- (void) setAudioStream {
  NSURL *url = [NSURL URLWithString:[playing url]];
  AudioStreamer *s = [[AudioStreamer alloc] initWithURL: url];
  [s autorelease];
  [self setStream:s];
}

- (void) seekToLastKnownTime {
  retrying = NO;
  [stream seekToTime:lastKnownSeekTime];
}

- (void)playbackStateChanged: (NSNotification *)aNotification {
  if ([stream errorCode] != 0) {
    /* Try a few times to re-initialize the stream just in case it was a fluke
     * which caused the stream to fail */
    NSLogd(@"Error on playback stream! count:%lu, Retrying...", tries);
    [self retry];
  } else if (retrying) {
    /* If we were already retrying things, then we'll get a notification as soon
       as the stream has enough packets to calculate the bit rate. This means
       that we can correctly seek into the song. After we seek, we've
       successfully re-synced the stream with what it was before the error
       happened */
    if ([stream calculatedBitRate] != 0) {
      [self seekToLastKnownTime];
    }
  }
}

- (void) retry {
  if (tries > 6) {
    NSLogd(@"Retried too many times, just nexting...");
    /* If we retried a bunch and it didn't work, the most likely cause is that
       the listed URL for the song has since expired. This probably also means
       that anything else in the queue (fetched at the same time) is also
       invalid, so empty the entire thing and have next fetch some more */
    [songs removeAllObjects];
    [self next];
    return;
  }

  double progress = [stream progress];
  tries++;
  retrying = YES;
  lastKnownSeekTime = progress;

  [self setAudioStream];
  [stream start];
}

- (void) play {
  if (stream) {
    if ([stream isPlaying]) {
      return;
    } else if ([stream isPaused]) {
      [stream pause];
      return;
    }

    NSLogd(@"Unknown state?!");
    return;
  }

  if ([songs count] == 0) {
    shouldPlaySongOnFetch = YES;
    [self fetchMoreSongs];
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

- (BOOL) isPaused {
  return [stream isPaused];
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
