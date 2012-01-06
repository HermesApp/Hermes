#import "Station.h"
#import "StationsController.h"
#import "HermesAppDelegate.h"

@implementation Station

@synthesize stationId, name, songs, stream, playing;

- (id) init {
  [self setSongs:[NSMutableArray arrayWithCapacity:10]];
  [self setPlaying:nil];
  [self setStream:nil];

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

  [[NSNotificationCenter defaultCenter] removeObserver:self];
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

  [[NSNotificationCenter defaultCenter]
    postNotificationName:@"songs.loaded" object:self];
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
      NSLogd(@"Ignoring play, stream already playing");
      return;
    } else if ([stream isPaused]) {
      [stream pause];
      NSLogd(@"pausing stream");
      return;
    }

    NSLogd(@"Unknown state?!");
    return;
  }

  if ([songs count] == 0) {
    NSLogd(@"no songs, fetching some more");
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
  return stream == nil || [stream isPaused];
}

- (void) next {
  if (playing == nil) {
    [songs removeObjectAtIndex:0];
    retrying = NO;
  } else {
    [self stop];
  }
  [self play];
}

- (void) stop {
  if (!stream || !playing) {
    return;
  }

  [stream stop];
  stream = nil;
  playing = nil;
}

- (void) copyFrom: (Station*) other {
  [songs removeAllObjects];
  /* Add the previously playing song to the front of the queue if
     there was one */
  if ([other playing] != nil) {
    [songs addObject:[other playing]];
  }
  [songs addObjectsFromArray:[other songs]];
  lastKnownSeekTime = other->lastKnownSeekTime;
  NSLogd(@"lastknown: %f", lastKnownSeekTime);
  if (lastKnownSeekTime > 0) {
    retrying = YES;
  }
}

- (NSScriptObjectSpecifier *) objectSpecifier {
  HermesAppDelegate *delegate = [NSApp delegate];
  StationsController *stationsc = [delegate stations];
  int index = [stationsc stationIndex:self];

  NSScriptClassDescription *containerClassDesc =
      [NSScriptClassDescription classDescriptionForClass:[NSApp class]];

  return [[NSIndexSpecifier alloc]
           initWithContainerClassDescription:containerClassDesc
           containerSpecifier:nil key:@"stations" index:index];
}

@end
