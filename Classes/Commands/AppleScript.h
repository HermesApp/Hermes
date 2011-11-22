//
//  AppleScript.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import <Cocoa/Cocoa.h>

// These match iTunes (4-char codes)
typedef enum {
  PlaybackStateStopped = 'stop',
  PlaybackStatePlaying = 'play',
  PlaybackStatePaused  = 'paus'
} PlaybackStates;

@interface PlayCommand : NSScriptCommand {} @end
@interface PauseCommand : NSScriptCommand {} @end
@interface PlayPauseCommand : NSScriptCommand {} @end
@interface SkipCommand : NSScriptCommand {} @end
@interface ThumbsUpCommand : NSScriptCommand {} @end
@interface ThumbsDownCommand : NSScriptCommand {} @end
@interface RaiseVolumeCommand : NSScriptCommand {} @end
@interface LowerVolumeCommand : NSScriptCommand {} @end
@interface FullVolumeCommand : NSScriptCommand {} @end
@interface MuteCommand : NSScriptCommand {} @end
@interface UnmuteCommand : NSScriptCommand {} @end
@interface TiredCommand : NSScriptCommand {} @end

@interface NSApplication (HermesScripting)
- (NSNumber*) volume;
- (void) setVolume: (NSNumber*) volume;
- (int) playbackState;
- (void) setPlaybackState: (int) state;
@end
