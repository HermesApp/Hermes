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

#import <Cocoa/Cocoa.h>
#include <AudioToolbox/AudioToolbox.h>

/* TODO: don't have this, buffer entire stream */
#define kNumAQBufs 16      // Number of audio queue buffers we allocate.
// Needs to be big enough to keep audio pipeline
// busy (non-zero number of queued buffers) but
// not so big that audio takes too long to begin
// (kNumAQBufs * kAQBufSize of data must be
// loaded before playback will start).
//
// Set LOG_QUEUED_BUFFERS to 1 to log how many
// buffers are queued at any time -- if it drops
// to zero too often, this value may need to
// increase. Min 3, typical 8-24.

#define kAQDefaultBufSize 2048  // Number of bytes in each audio queue buffer
// Needs to be big enough to hold a packet of
// audio from the audio file. If number is too
// large, queuing of audio before playback starts
// will take too long.
// Highly compressed files can use smaller
// numbers (512 or less). 2048 should hold all
// but the largest packets. A buffer size error
// will occur if this number is too small.

#define kAQMaxPacketDescs 512  // Number of packet descriptions in our array

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

extern NSString * const ASStatusChangedNotification;

struct queued_packet;

/**
 * @brief Class for streaming audio over an HTTP stream
 *
 * This class is implemented on top of Apple's AudioQueue framework. This
 * framework is much too low-level for must use cases, so this class
 * encapsulates the functionality to provide a nicer interface. The interface
 * still requires some management, but it is far more sane than dealing with the
 * AudioQueue structures yourself.
 *
 * This class is essentially a pipeline of three components to get audio to the
 * speakers:
 *
 *      CFReadStream -> AudioFileStream -> AudioQueue
 *
 * CFReadStream:
 *  The method of reading HTTP data is using the low-level CFReadStream class
 *  because it allows configuration of proxies and scheduling/rescheduling on the
 *  event loop. All data read from the HTTP stream is piped into the
 *  AudioFileStream which then parses all of the data. This stage of the
 *  pipeline also flags that events are happening to prevent a timeout. All
 *  network activity occurs on the thread which started the audio stream.
 *
 * AudioFileStream:
 *  This stage is implemented by Apple frameworks, and parses all audio data. It
 *  is composed of two callbacks which receive data. The first callback invoked
 *  in series is one which is notified whenever a new property is known about
 *  the audio stream being received. Once all properties have been read, the
 *  second callback beings to be invoked, and this callback is responsible for
 *  dealing with packets.
 *
 *  The second callback is invoked whenever complete "audio packets" are
 *  available to send to the audio queue. This stage is invoked on the call
 *  stack of the stream which received the data (synchronously with receiving
 *  the data).
 *
 *  Packets received are buffered in a static set of buffers allocated by the
 *  audio queue instance. When a buffer is full, it is committed to the audio
 *  queue, and then the next buffer is moved on to. Multiple packets can
 *  possibly fit in one buffer. When committing a buffer, if there are no more
 *  buffers available, then the http read stream is unscheduled from the run
 *  loop and all currently received data is stored aside for later processing.
 *
 * AudioQueue:
 *  This final stage is also implemented by Apple, and receives all of the full
 *  buffers of data from the AudioFileStream's parsed packets. The
 *  implementation manages its own set of threads, and callbacks are invoked on
 *  the internal threads, not the main thread. The two callbacks that the audio
 *  stream is interested in are playback state changing and audio buffers being
 *  freed. In both cases, a message is queued for delivery on the main thread to
 *  prevent synchronization issues.
 *
 *  When a buffer is freed, then it is marked as so, and if the stream was
 *  waiting for a buffer to be freed a message to empty the queue as much as
 *  possible is sent to the main thread's run loop. Otherwise no extra action
 *  need be performed.
 *
 *  The main purpose of knowing when the playback state changes is to change the
 *  state of the player accordingly.
 *
 * =============================================================================
 *
 * Errors
 *  There are a large number of places where error can happen, and the stream
 *  can bail out at any time with an error. Each error has its own code and
 *  corresponding string representation. Any error will halt the entire audio
 *  stream and cease playback.
 *
 *  Some errors might want to be handled by the manager of the AudioStreamer
 *  class, but others normally indicate that the remote stream just won't work.
 *  Occasionally errors might reflect a lack of local resources.
 *
 * =============================================================================
 *
 * Seeking
 *  To seek inside an audio stream, the bit rate must be known along with some
 *  other metadata, but this is not known until after the stream has started.
 *  For this reason the seek can fail if not enough data is known yet.
 *
 *  If a seek succeeds, however, the actual method of doing so is as follows.
 *  First, open a stream at position 0 and collect data about the stream, when
 *  the seek is requested, cancel the stream and re-open the connection with the
 *  proper byte offset. This second stream is then used to put data through the
 *  pipelines.
 *
 * =============================================================================
 *
 * General notes
 *  An audio stream is a one-shot thing. Once initialized, the source cannot be
 *  changed and a single audio stream cannot be re-used. To do this, multiple
 *  AudioStreamer objects need to be created/managed.
 *
 */
@interface AudioStreamer : NSObject {
  /* Properties specified at creation */
  NSURL *url;

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
  NSInteger fileLength;      /* length of file, set from http headers */
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
  AudioQueueBufferRef audioQueueBuffer[kNumAQBufs];
  AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];
  size_t packetsFilled;         /* number of valid entries in packetDescs */
  size_t bytesFilled;           /* bytes in use in the pending buffer */
  unsigned int fillBufferIndex; /* index of the pending buffer */
  bool inuse[kNumAQBufs];       /* which buffers have yet to be processed */
  NSInteger buffersUsed;        /* Number of buffers in use */

  /* cache state (see above description) */
  bool waitingOnBuffer;
  struct queued_packet *queued_head;
  struct queued_packet *queued_tail;

  /* Internal meatadata about errors and state */
  AudioStreamerState state_;
  AudioStreamerErrorCode errorCode;
  NSError *networkError;
  OSStatus err;

  /* Miscellaneous metadata */
  bool discontinuous;        /* flag to indicate the middle of a stream */
  NSInteger seekByteOffset;  /* position with the file to seek */
  double seekTime;
  UInt64 processedPacketsCount;
  UInt64 processedPacketsSizeTotal;
  double lastProgress;       /* last calculated progress point */
}

@property AudioStreamerErrorCode errorCode;
@property (readonly) AudioStreamerState state;
@property (readonly) NSDictionary *httpHeaders;
@property (readonly) NSError *networkError;

+ (NSString *)stringForErrorCode:(AudioStreamerErrorCode)anErrorCode;

- (id)initWithURL:(NSURL *)aURL;
- (void)start;
- (void)stop;
- (void)pause;
- (void)play;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)isWaiting;
- (BOOL)isDone;
- (BOOL)seekToTime:(double)newSeekTime;
- (double)calculatedBitRate;
- (BOOL)setVolume:(double)volume;
- (double)duration;
- (double)progress;

@end
