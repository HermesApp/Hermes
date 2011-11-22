//
//  AppleScript.m
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "AppleScript.h"
#import "HermesAppDelegate.h"

int savedVolume = 0;

@implementation PlayCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	return [NSNumber numberWithBool:[playback play]];
}
@end

@implementation PauseCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	return [NSNumber numberWithBool:[playback pause]];
}
@end

@implementation PlayPauseCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	[playback playpause:self];
  return self;
}
@end

@implementation SkipCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	[playback next:self];
  return self;
}
@end
@implementation ThumbsUpCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	[playback like:self];
  return self;
}
@end
@implementation ThumbsDownCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	[playback dislike:self];
  return self;
}
@end
@implementation RaiseVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
  int volume = [playback getIntVolume];
  [playback setIntVolume:volume + 7];
  NSLogd(@"Raised volume to: %d", [playback getIntVolume]);
  return self;
}
@end
@implementation LowerVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
  int volume = [playback getIntVolume];
  [playback setIntVolume:volume - 7];
  NSLogd(@"Lowered volume to: %d", [playback getIntVolume]);
  return self;
}
@end
@implementation FullVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	[playback setIntVolume:100];
  NSLogd(@"Changed volume to: %d", [playback getIntVolume]);
  return self;
}
@end
@implementation MuteCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
  savedVolume = [playback getIntVolume];
	[playback setIntVolume:0];
  NSLogd(@"Changed volume to: %d", [playback getIntVolume]);
  return self;
}
@end
@implementation UnmuteCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
	[playback setIntVolume:savedVolume];
  NSLogd(@"Changed volume to: %d", [playback getIntVolume]);
  return self;
}
@end
@implementation TiredCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [[NSApp delegate] playback];
  [playback tired:self];
  return self;
}
@end

@implementation NSApplication (HermesScripting)

- (NSNumber*) volume {
  PlaybackController *playback = [[NSApp delegate] playback];
  return [NSNumber numberWithInt:[playback getIntVolume]];
}

- (void) setVolume: (NSNumber*) vol {
  PlaybackController *playback = [[NSApp delegate] playback];
  [playback setIntVolume:[vol intValue]];
}

- (int) playbackState {
  PlaybackController *playback = [[NSApp delegate] playback];
  Station *playing = [playback playing];
  if (playing == nil) {
    return PlaybackStateStopped;
  } else if ([[playing stream] isPaused]) {
    return PlaybackStatePaused;
  }
  return PlaybackStatePlaying;
}

- (void) setPlaybackState: (int) state {
  PlaybackController *playback = [[NSApp delegate] playback];
  switch (state) {
    case PlaybackStateStopped:
    case PlaybackStatePaused:
      [playback pause];
      break;

    case PlaybackStatePlaying:
      [playback play];
      break;

    default:
      NSLog(@"Invalid playback state: %d", state);
  }
}

@end
