//
//  AudioStreamer.h
//  StreamingAudioPlayer
//
//  Created by Matt Gallagher on 27/09/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

/* This file has been heavily modified since its original distribution bytes
   Alex Crichton for the Hermes project */

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

/* Maximum number of packets which can be contained in one buffer */
#define kAQMaxPacketDescs 512

typedef enum {
  AS_INITIALIZED = 0,
  AS_WAITING_FOR_DATA,
  AS_WAITING_FOR_QUEUE_TO_START,
  AS_PLAYING,
  AS_PAUSED,
  AS_DONE,
  AS_STOPPED
} AudioStreamerState;

typedef enum
{
  AS_NO_ERROR = 0,
  AS_NETWORK_CONNECTION_FAILED,
  AS_FILE_STREAM_GET_PROPERTY_FAILED,
  AS_FILE_STREAM_SET_PROPERTY_FAILED,
  AS_FILE_STREAM_SEEK_FAILED,
  AS_FILE_STREAM_PARSE_BYTES_FAILED,
  AS_FILE_STREAM_OPEN_FAILED,
  AS_FILE_STREAM_CLOSE_FAILED,
  AS_AUDIO_DATA_NOT_FOUND,
  AS_AUDIO_QUEUE_CREATION_FAILED,
  AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,
  AS_AUDIO_QUEUE_ENQUEUE_FAILED,
  AS_AUDIO_QUEUE_ADD_LISTENER_FAILED,
  AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,
  AS_AUDIO_QUEUE_START_FAILED,
  AS_AUDIO_QUEUE_PAUSE_FAILED,
  AS_AUDIO_QUEUE_BUFFER_MISMATCH,
  AS_AUDIO_QUEUE_DISPOSE_FAILED,
  AS_AUDIO_QUEUE_STOP_FAILED,
  AS_AUDIO_QUEUE_FLUSH_FAILED,
  AS_AUDIO_STREAMER_FAILED,
  AS_GET_AUDIO_TIME_FAILED,
  AS_AUDIO_BUFFER_TOO_SMALL,
  AS_TIMED_OUT
} AudioStreamerErrorCode;

typedef enum {
  AS_DONE_STOPPED,
  AS_DONE_ERROR,
  AS_DONE_EOF,
  AS_NOT_DONE
} AudioStreamerDoneReason;

extern NSString * const ASStatusChangedNotification;
extern NSString * const ASBitrateReadyNotification;

struct queued_packet;

/**
 * This class is implemented on top of Apple's AudioQueue framework. This
 * framework is much too low-level for must use cases, so this class
 * encapsulates the functionality to provide a nicer interface. The interface
 * still requires some management, but it is far more sane than dealing with the
 * AudioQueue structures yourself.
 *
 * This class is essentially a pipeline of three components to get audio to the
 * speakers:
 *
 *              CFReadStream => AudioFileStream => AudioQueue
 *
 * ### CFReadStream
 *
 * The method of reading HTTP data is using the low-level CFReadStream class
 * because it allows configuration of proxies and scheduling/rescheduling on the
 * event loop. All data read from the HTTP stream is piped into the
 * AudioFileStream which then parses all of the data. This stage of the pipeline
 * also flags that events are happening to prevent a timeout. All network
 * activity occurs on the thread which started the audio stream.
 *
 * ### AudioFileStream
 *
 * This stage is implemented by Apple frameworks, and parses all audio data.  It
 * is composed of two callbacks which receive data. The first callback invoked
 * in series is one which is notified whenever a new property is known about the
 * audio stream being received. Once all properties have been read, the second
 * callback beings to be invoked, and this callback is responsible for dealing
 * with packets.
 *
 * The second callback is invoked whenever complete "audio packets" are
 * available to send to the audio queue. This stage is invoked on the call stack
 * of the stream which received the data (synchronously with receiving the
 * data).
 *
 * Packets received are buffered in a static set of buffers allocated by the
 * audio queue instance. When a buffer is full, it is committed to the audio
 * queue, and then the next buffer is moved on to. Multiple packets can possibly
 * fit in one buffer. When committing a buffer, if there are no more buffers
 * available, then the http read stream is unscheduled from the run loop and all
 * currently received data is stored aside for later processing.
 *
 * ### AudioQueue
 *
 * This final stage is also implemented by Apple, and receives all of the full
 * buffers of data from the AudioFileStream's parsed packets. The implementation
 * manages its own set of threads, but callbacks are invoked on the main thread.
 * The two callbacks that the audio stream is interested in are playback state
 * changing and audio buffers being freed.
 *
 * When a buffer is freed, then it is marked as so, and if the stream was
 * waiting for a buffer to be freed a message to empty the queue as much as
 * possible is sent to the main thread's run loop. Otherwise no extra action
 * need be performed.
 *
 * The main purpose of knowing when the playback state changes is to change the
 * state of the player accordingly.
 *
 * ## Errors
 *
 * There are a large number of places where error can happen, and the stream can
 * bail out at any time with an error. Each error has its own code and
 * corresponding string representation. Any error will halt the entire audio
 * stream and cease playback. Some errors might want to be handled by the
 * manager of the AudioStreamer class, but others normally indicate that the
 * remote stream just won't work.  Occasionally errors might reflect a lack of
 * local resources.
 *
 * Error information can be learned from the errorCode property and the
 * stringForErrorCode: method.
 *
 * ## Seeking
 *
 * To seek inside an audio stream, the bit rate must be known along with some
 * other metadata, but this is not known until after the stream has started.
 * For this reason the seek can fail if not enough data is known yet.
 *
 * If a seek succeeds, however, the actual method of doing so is as follows.
 * First, open a stream at position 0 and collect data about the stream, when
 * the seek is requested, cancel the stream and re-open the connection with the
 * proper byte offset. This second stream is then used to put data through the
 * pipelines.
 *
 * ## Example usage
 *
 * An audio stream is a one-shot thing. Once initialized, the source cannot be
 * changed and a single audio stream cannot be re-used. To do this, multiple
 * AudioStreamer objects need to be created/managed.
 */
@interface AudioStreamer : NSObject {
  /* Properties specified before the stream starts. None of these properties
   * should be changed after the stream has started or otherwise it could cause
   * internal inconsistencies in the stream. Detail explanations of each
   * property can be found in the source */
  NSURL           *url;
  int             proxyType;  /* defaults to whatever the system says */
  NSString        *proxyHost;
  int             proxyPort;
  AudioFileTypeID fileType;
  UInt32          bufferSize; /* attempted to be guessed, but fallback here */
  UInt32          bufferCnt;
  BOOL            bufferInfinite;
  int             timeoutInterval;

  /* Creates as part of the [start] method */
  CFReadStreamRef stream;

  /* Timeout management */
  NSTimer *timeout; /* timer managing the timeout event */
  BOOL unscheduled; /* flag if the http stream is unscheduled */
  BOOL rescheduled; /* flag if the http stream was rescheduled */
  int events;       /* events which have happened since the last tick */

  /* Once the stream has bytes read from it, these are created */
  NSDictionary *httpHeaders;
  AudioFileStreamID audioFileStream;

  /* The audio file stream will fill in these parameters */
  UInt64 fileLength;         /* length of file, set from http headers */
  UInt64 dataOffset;         /* offset into the file of the start of stream */
  UInt64 audioDataByteCount; /* number of bytes of audio data in file */
  AudioStreamBasicDescription asbd; /* description of audio */

  /* Once properties have been read, packets arrive, and the audio queue is
     created once the first packet arrives */
  AudioQueueRef audioQueue;
  UInt32 packetBufferSize;  /* guessed from audioFileStream */

  /* When receiving audio data, raw data is placed into these buffers. The
   * buffers are essentially a "ring buffer of buffers" as each buffer is cycled
   * through and then freed when not in use. Each buffer can contain one or many
   * packets, so the packetDescs array is a list of packets which describes the
   * data in the next pending buffer (used to enqueue data into the AudioQueue
   * structure */
  AudioQueueBufferRef *buffers;
  AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];
  UInt32 packetsFilled;         /* number of valid entries in packetDescs */
  UInt32 bytesFilled;           /* bytes in use in the pending buffer */
  unsigned int fillBufferIndex; /* index of the pending buffer */
  BOOL *inuse;                  /* which buffers have yet to be processed */
  UInt32 buffersUsed;           /* Number of buffers in use */

  /* cache state (see above description) */
  bool waitingOnBuffer;
  struct queued_packet *queued_head;
  struct queued_packet *queued_tail;

  /* Internal metadata about errors and state */
  AudioStreamerState state_;
  AudioStreamerErrorCode errorCode;
  NSError *networkError;
  OSStatus err;

  /* Miscellaneous metadata */
  bool discontinuous;        /* flag to indicate the middle of a stream */
  UInt64 seekByteOffset;     /* position with the file to seek */
  double seekTime;
  bool seeking;              /* Are we currently in the process of seeking? */
  double lastProgress;       /* last calculated progress point */
  UInt64 processedPacketsCount;     /* bit rate calculation utility */
  UInt64 processedPacketsSizeTotal; /* helps calculate the bit rate */
  bool   bitrateNotification;       /* notified that the bitrate is ready */
}

/** @name Creating an audio stream */

/**
 * Allocate a new audio stream with the specified url
 *
 * The created stream has not started playback. This gives an opportunity to
 * configure the rest of the stream as necessary. To start playback, send the
 * stream an explicit 'start' message.
 *
 * @param url the remote source of audio
 * @return the stream to configure and being playback with
 */
+ (AudioStreamer*) streamWithURL:(NSURL*)url;

/** @name Properties of the audio stream */

/**
 * If an error occurs on the stream, then this variable is set with the code
 * corresponding to the error
 *
 * By default this is AS_NO_ERROR.
 */
@property AudioStreamerErrorCode errorCode;

/**
 * Converts an error code to a string
 *
 * @param anErrorCode the code to convert, usually from the errorCode field
 * @return the string description of the error code (as best as possible)
 */
+ (NSString*) stringForErrorCode:(AudioStreamerErrorCode)anErrorCode;

/**
 * Headers received from the remote source
 *
 * Used to determine file size, but other information may be useful as well
 */
@property (readonly) NSDictionary *httpHeaders;

/* TODO: get rid of this */
@property (readonly) NSError *networkError;

/**
 * The remote resource that this stream is playing, this is a read-only property
 * and cannot be changed after creation
 */
@property (readonly) NSURL *url;

/**
 * The number of audio buffers to have
 *
 * Each audio buffer contains one or more packets of audio data. This amount is
 * only relevant if infinite buffering is turned off. This is the amount of data
 * which is stored in memory while playing. Once this memory is full, the remote
 * connection will not be read and will not receive any more data until one of
 * the buffers becomes available.
 *
 * With infinite buffering turned on, this number should be at least 3 or so to
 * make sure that there's always data to be read. With infinite buffering turned
 * off, this should be a number to not consume too much memory, but to also keep
 * up with the remote data stream. The incoming data should always be able to
 * stay ahead of these buffers being filled
 *
 * Default: 16
 */
@property (readwrite) UInt32 bufferCnt;

/**
 * The default size for each buffer allocated
 *
 * Each buffer's size is attempted to be guessed from the audio stream being
 * received. This way each buffer is tuned for the audio stream itself. If this
 * inferring of the buffer size fails, however, this is used as a fallback as
 * how large each buffer should be.
 *
 * If you find that this is being used, then it should be coordinated with
 * bufferCnt above to make sure that the audio stays responsive and slightly
 * behind the HTTP stream
 *
 * Default: 2048
 */
@property (readwrite) UInt32 bufferSize;

/**
 * The file type of this audio stream
 *
 * This is an optional parameter. If not specified, then then the file type will
 * be guessed. First, the MIME type of the response is used to guess the file
 * type, and if that fails the extension on the url is used. If that fails as
 * well, then the default is an MP3 stream.
 *
 * If this property is set, then no inferring is done and that file type is
 * always used.
 *
 * Default: (guess)
 */
@property (readwrite) AudioFileTypeID fileType;

/**
 * Flag if to infinitely buffer data
 *
 * If this flag is set to NO, then a statically sized buffer is used as
 * determined by bufferCnt and bufferSize above and the read stream will be
 * descheduled when those fill up. This limits the bandwidth consumed to the
 * remote source and also limits memory usage.
 *
 * If, however, you wish to hold the entire stream in memory, then you can set
 * this flag to YES. In this state, the stream will be entirely downloaded,
 * regardless if the buffers are full or not. This way if the network stream
 * cuts off halfway through a song, the rest of the song will be downloaded
 * locally to finish off. The next song might still be in trouble, however...
 * With this turned on, memory usage will be higher because the entire stream
 * will be downloaded as fast as possible, and the bandwidth to the remote will
 * also be consumed. Depending on the situation, this might not be that bad of
 * a problem.
 *
 * Default: NO
 */
@property (readwrite) BOOL bufferInfinite;

/**
 * Interval to consider timeout if no network activity is seen
 *
 * When downloading audio data from a remote source, this is the interval in
 * which to consider it a timeout if no data is received. If the stream is
 * paused, then that time interval is not counted. This only counts if we are
 * waiting for data and an amount of time larger than this elapses.
 *
 * The units of this variable is seconds.
 *
 * Default: 10
 */
@property (readwrite) int timeoutInterval;

/**
 * Set an HTTP proxy for this stream
 *
 * @param host the address/hostname of the remote host
 * @param port the port of the proxy
 */
- (void) setHTTPProxy:(NSString*)host port:(int)port;

/**
 * Set SOCKS proxy for this stream
 *
 * @param host the address/hostname of the remote host
 * @param port the port of the proxy
 */
- (void) setSOCKSProxy:(NSString*)host port:(int)port;

/** @name Management of the stream and testing state */

/**
 * Starts playback of this audio stream.
 *
 * This method can only be invoked once, and other methods will not work before
 * this method has been invoked. All properties (like proxies) must be set
 * before this method is invoked.
 *
 * @return YES if the stream was started, or NO if the stream was previously
 *         started and this had no effect.
 */
- (BOOL) start;

/**
 * Stop all streams, cleaning up resources and preventing all further events
 * from occurring.
 *
 * This method may be invoked at any time from any point of the audio stream as
 * a signal of error happening. This method sets the state to AS_STOPPED if it
 * isn't already AS_STOPPED or AS_DONE.
 */
- (void) stop;

/**
 * Pause the audio stream if playing
 *
 * @return YES if the audio stream was paused, or NO if it was not in the
 *         AS_PLAYING state or an error occurred.
 */
- (BOOL) pause;

/**
 * Plays the audio stream if paused
 *
 * @return YES if the audio stream entered into the AS_PLAYING state, or NO if
 *         any other error or bad state was encountered.
 */
- (BOOL) play;

/**
 * Tests whether the stream is playing
 *
 * @return YES if the stream is playing, or NO Otherwise
 */
- (BOOL) isPlaying;

/**
 * Tests whether the stream is paused
 *
 * A stream is not paused if it is waiting for data. A stream is paused if and
 * only if it used to be playing, but the it was paused via the pause method.
 *
 * @return YES if the stream is paused, or NO Otherwise
 */
- (BOOL) isPaused;

/**
 * Tests whether the stream is waiting
 *
 * This could either mean that we're waiting on data from the network or waiting
 * for some event with the AudioQueue instance.
 *
 * @return YES if the stream is waiting, or NO Otherwise
 */
- (BOOL) isWaiting;

/**
 * Tests whether the stream is done with all operation
 *
 * A stream can be 'done' if it either hits an error or consumes all audio data
 * from the remote source.
 *
 * @return YES if the stream is done, or NO Otherwise
 */
- (BOOL) isDone;

/**
 * When isDone returns true, this will return the reason that the stream has
 * been flagged as being done.
 *
 * @return the reason for the stream being done, or that it's not done.
 */
- (AudioStreamerDoneReason) doneReason;

/** @name Calculated properties and modifying the stream (all can fail) */

/**
 * Seek to a specified time in the audio stream
 *
 * This can only happen once the bit rate of the stream is known because
 * otherwise the byte offset to the stream is not known. For this reason the
 * function can fail to actually seek.
 *
 * Additionally, seeking to a new time involves re-opening the audio stream with
 * the remote source, although this is done under the hood.
 *
 * @param newSeekTime the time in seconds to seek to
 * @return YES if the stream will be seeking, or NO if the stream did not have
 *         enough information available to it to seek to the specified time.
 */
- (BOOL) seekToTime:(double)newSeekTime;

/**
 * Calculates the bit rate of the stream
 *
 * All packets received so far contribute to the calculation of the bit rate.
 * This is used internally to determine other factors like duration and
 * progress.
 *
 * @param ret the double to fill in with the bit rate on success.
 * @return YES if the bit rate could be calculated with a high degree of
 *         certainty, or NO if it could not be.
 */
- (BOOL) calculatedBitRate:(double*)ret;

/**
 * Attempt to set the volume on the audio queue
 *
 * @param volume the volume to set the stream to in the range 0.0-1.0 where 1.0
 *        is the loudest and 0.0 is silent.
 * @return YES if the volume was set, or NO if the audio queue wasn't to have
 *         the volume ready to be set. When the state for this audio streamer
 *         changes internally to have a stream, then setVolume: will work
 */
- (BOOL) setVolume:(double)volume;

/**
 * Calculates the duration of the audio stream in seconds
 *
 * Uses information about the size of the file and the calculated bit rate to
 * determine the duration of the stream.
 *
 * @param ret where to fill in with the duration of the stream on success.
 * @return YES if ret contains the duration of the stream, or NO if the duration
 *         could not be determined. In the NO case, the contents of ret are
 *         undefined
 */
- (BOOL) duration:(double*)ret;

/**
 * Calculate the progress into the stream, in seconds
 *
 * The AudioQueue instance is polled to determine the current time into the
 * stream, and this is returned.
 *
 * @param ret a double which is filled in with the progress of the stream. The
 *        contents are undefined if NO is returned.
 * @return YES if the progress of the stream was determined, or NO if the
 *         progress could not be determined at this time.
 */
- (BOOL) progress:(double*)ret;

@end
