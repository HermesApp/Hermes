#import "HermesAppDelegate.h"
#import "Pandora/Station.h"
#import "PreferencesController.h"
#import "StationsController.h"
#import "Notifications.h"
#import "ASPlaylist.h"

@implementation Station

- (id) init {
  if (!(self = [super init])) return nil;

  songs = [NSMutableArray arrayWithCapacity:10];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fetchMoreSongs:)
             name:ASRunningOutOfSongs
           object:self];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fetchMoreSongs:)
             name:ASNoSongsLeft
           object:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(configureNewStream:)
             name:ASCreatedNewStream
           object:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(newSongPlaying:)
             name:ASNewSongPlaying
           object:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(attemptingNewSong:)
             name:ASAttemptingNewSong
           object:self];

  return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
  if ((self = [self init])) {
    [self setStationId:[aDecoder decodeObjectForKey:@"stationId"]];
    [self setName:[aDecoder decodeObjectForKey:@"name"]];
    [self setVolume:[aDecoder decodeFloatForKey:@"volume"]];
    [self setCreated:[aDecoder decodeInt32ForKey:@"created"]];
    [self setToken:[aDecoder decodeObjectForKey:@"token"]];
    [self setShared:[aDecoder decodeBoolForKey:@"shared"]];
    [self setAllowAddMusic:[aDecoder decodeBoolForKey:@"allowAddMusic"]];
    [self setAllowRename:[aDecoder decodeBoolForKey:@"allowRename"]];
    lastKnownSeekTime = [aDecoder decodeFloatForKey:@"lastKnownSeekTime"];
    [songs addObject:[aDecoder decodeObjectForKey:@"playing"]];
    [songs addObjectsFromArray:[aDecoder decodeObjectForKey:@"songs"]];
    [urls addObject:[aDecoder decodeObjectForKey:@"playingURL"]];
    [urls addObjectsFromArray:[aDecoder decodeObjectForKey:@"urls"]];
    if ([songs count] != [urls count]) {
      [songs removeAllObjects];
      [urls removeAllObjects];
    }
    [Station addStation:self];
  }
  return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_stationId forKey:@"stationId"];
  [aCoder encodeObject:_name forKey:@"name"];
  [aCoder encodeObject:_playingSong forKey:@"playing"];
  double seek = -1;
  if (_playingSong) {
    [stream progress:&seek];
  }
  [aCoder encodeFloat:seek forKey:@"lastKnownSeekTime"];
  [aCoder encodeFloat:volume forKey:@"volume"];
  [aCoder encodeInt32:_created forKey:@"created"];
  [aCoder encodeObject:songs forKey:@"songs"];
  [aCoder encodeObject:urls forKey:@"urls"];
  [aCoder encodeObject:[self playing] forKey:@"playingURL"];
  [aCoder encodeObject:_token forKey:@"token"];
  [aCoder encodeBool:_shared forKey:@"shared"];
  [aCoder encodeBool:_allowAddMusic forKey:@"allowAddMusic"];
  [aCoder encodeBool:_allowRename forKey:@"allowRename"];
}

- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
}

- (BOOL) isEqual:(id)object {
  return [_stationId isEqual:[object stationId]];
}

- (void) attemptingNewSong:(NSNotification*) notification {
    _playingSong = songs[0];
    [songs removeObjectAtIndex:0];
}

- (void) fetchMoreSongs:(NSNotification*) notification {
  shouldPlaySongOnFetch = YES;
  [radio fetchPlaylistForStation:self];
}

- (void) setRadio:(Pandora *)pandora {
  @synchronized(radio) {
    if (radio != nil) {
      [[NSNotificationCenter defaultCenter] removeObserver:self
                                                      name:nil
                                                    object:radio];
    }
    radio = pandora;

    NSString *n = [NSString stringWithFormat:@"hermes.fragment-fetched.%@", _token];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(songsLoaded:)
                                                 name:n
                                               object:nil];
  }
}

- (void) songsLoaded: (NSNotification*)not {
  NSArray *more = [not userInfo][@"songs"];
  NSMutableArray *qualities = [[NSMutableArray alloc] init];
  if (more == nil) return;

  for (Song *s in more) {
    NSURL *url = nil;
    switch (PREF_KEY_INT(DESIRED_QUALITY)) {
      case QUALITY_HIGH:
        [qualities addObject:@"high"];
        url = [NSURL URLWithString:[s highUrl]];
        break;
      case QUALITY_LOW:
        [qualities addObject:@"low"];
        url = [NSURL URLWithString:[s lowUrl]];
        break;

      case QUALITY_MED:
      default:
        [qualities addObject:@"med"];
        url = [NSURL URLWithString:[s medUrl]];
        break;
    }
    [urls addObject:url];
    [songs addObject:s];
  }
  if (shouldPlaySongOnFetch) {
    [self play];
  }
  shouldPlaySongOnFetch = NO;
  NSLogd(@"Received %@ from %@ with qualities: %@", not.name, not.object, [qualities componentsJoinedByString:@" "]);
}

- (void) configureNewStream:(NSNotification*) notification {
  assert(stream == [notification userInfo][@"stream"]);
  [stream setBufferInfinite:TRUE];
  [stream setTimeoutInterval:15];

  if (PREF_KEY_VALUE(PROXY_AUDIO)) {
    switch ([PREF_KEY_VALUE(ENABLED_PROXY) intValue]) {
      case PROXY_HTTP:
        [stream setHTTPProxy:PREF_KEY_VALUE(PROXY_HTTP_HOST)
                        port:[PREF_KEY_VALUE(PROXY_HTTP_PORT) intValue]];
        break;
      case PROXY_SOCKS:
        [stream setSOCKSProxy:PREF_KEY_VALUE(PROXY_SOCKS_HOST)
                         port:[PREF_KEY_VALUE(PROXY_SOCKS_PORT) intValue]];
        break;
      default:
        break;
    }
  }
}

- (void) newSongPlaying:(NSNotification*) notification {
  assert([songs count] == [urls count]);
  [[NSNotificationCenter defaultCenter]
        postNotificationName:StationDidPlaySongNotification
                      object:self
                    userInfo:nil];
}

- (NSString*) streamNetworkError {
  if ([stream errorCode] == AS_NETWORK_CONNECTION_FAILED) {
    return [[stream networkError] localizedDescription];
  }
  return [AudioStreamer stringForErrorCode:[stream errorCode]];
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

- (void) clearSongList {
  [songs removeAllObjects];
  [super clearSongList];
}

static NSMutableDictionary *stations = nil;

+ (Station*) stationForToken:(NSString*)stationId{
  if (stations == nil)
    return nil;
  return stations[stationId];
}

+ (void) addStation:(Station*) s {
  if (stations == nil) {
    stations = [NSMutableDictionary dictionary];
  }
  stations[[s stationId]] = s;
}

+ (void) removeStation:(Station*) s {
  if (stations == nil)
    return;
  [stations removeObjectForKey:[s stationId]];
}

@end
