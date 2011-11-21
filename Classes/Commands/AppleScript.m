//
//  AppleScript.m
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "AppleScript.h"
#import "HermesAppDelegate.h"

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
	[playback setIntVolume:0];
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
@end
