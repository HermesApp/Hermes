//
//  ASPlaylist.h
//  AudioStreamer
//
//  Created by Alex Crichton on 8/21/12.
//
//

#import "AudioStreamer.h"

extern NSString * const ASNewSongPlaying;
extern NSString * const ASNoSongsLeft;
extern NSString * const ASRunningOutOfSongs;
extern NSString * const ASCreatedNewStream;
extern NSString * const ASStreamError;
extern NSString * const ASAttemptingNewSong;
extern NSString * const ASBitrateReadyNotification;

/**
 * The ASPlaylist class is intended to be a wrapper around the AudioStreamer
 * class for a more robust interface if one is desired. It also manages a queue
 * of songs to play and automatically switches from one song to the next when
 * playback finishes.
 */
@interface ASPlaylist : NSObject {
  BOOL retrying;              /* Are we retrying the current url? */
  BOOL nexting;               /* Are we in the middle of nexting? */
  BOOL stopping;              /* Are we in the middle of stopping? */
  BOOL volumeSet;             /* TRUE if the volume has been set on the stream */
  double lastKnownSeekTime;   /* time to seek to */
  double volume;              /* volume for all streams on this playlist */

  NSInteger tries;            /* # of retry attempts */
  NSMutableArray *urls;       /* list of URLs to play */
  AudioStreamer *stream;      /* stream that is playing */
}

/**
 * The currently playing URL.
 *
 * This is nil of no url has ever been playing.
 */
@property NSURL *playing;

/** @name Managing the playlist */

/**
 * Start playing songs on the playlist, or resume playback.
 *
 * This will send out notifications for more songs if we're running low on songs
 * or are out of songs completely to play.
 */
- (void) play;

/**
 * Restart the currently playing song.
 */
- (void)replay;

/**
 * Pause playback on the playlist.
 *
 * This has no effect if the playlist is already paused or wasn't playing a song
 */
- (void) pause;

/**
 * Stops playing the current song and forgets about it.
 *
 * The song is stopped and internally all state about the song is thrown away
 */
- (void) stop;

/**
 * Goes to the next song in the playlist
 *
 * This can trigger notifications about songs running low or associated events.
 */
- (void) next;

/** @name Interface to AudioStreamer */
- (BOOL) isPaused;
- (BOOL) isPlaying;
- (BOOL) isIdle;
- (BOOL) isError;
- (void) setVolume:(double)volume;
- (BOOL) duration:(double *)ret;
- (BOOL) progress:(double *)ret;

/** @name Miscellaneous */

/**
 * If the stream has stopped for a network error, this retries playing the
 * stream
 */
- (void) retry;

/**
 * Removes all songs from the internal list of songs. This does not trigger
 * notifications about songs running low.
 */
- (void) clearSongList;

/**
 * Adds a new song to the playlist, optionally starting playback.
 */
- (void) addSong:(NSURL*)url play:(BOOL)play;

@end
