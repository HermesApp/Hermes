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

typedef enum
{
  AS_INITIALIZED = 0,
  AS_STARTING_FILE_THREAD,
  AS_WAITING_FOR_DATA,
  AS_FLUSHING_EOF,
  AS_WAITING_FOR_QUEUE_TO_START,
  AS_PLAYING,
  AS_BUFFERING,
  AS_STOPPING,
  AS_STOPPED,
  AS_PAUSED
} AudioStreamerState;

typedef enum
{
  AS_NO_STOP = 0,
  AS_STOPPING_EOF,
  AS_STOPPING_USER_ACTION,
  AS_STOPPING_ERROR,
  AS_STOPPING_TEMPORARILY
} AudioStreamerStopReason;

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
  AS_AUDIO_BUFFER_TOO_SMALL
} AudioStreamerErrorCode;

extern NSString * const ASStatusChangedNotification;

struct queued_packet;

@interface AudioStreamer : NSObject {
  /* Properties specified at creation */
  NSURL *url;

  /* Creates as part of the [start] method */
  CFReadStreamRef stream;

  /* Once the stream has bytes read from it, these are created */
  NSDictionary *httpHeaders;
  AudioFileStreamID audioFileStream;  // the audio file stream parser

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

  /* cache state */
  bool waitingOnBuffer;
  struct queued_packet *queued_head;
  struct queued_packet *queued_tail;

  /* Internal meatadata about errors and state */
  AudioStreamerState state_;
  AudioStreamerStopReason stopReason;
  AudioStreamerErrorCode errorCode;
  NSError *networkError;
  OSStatus err;

  bool discontinuous;      // flag to indicate middle of the stream

  NSInteger seekByteOffset;  // Seek offset within the file in bytes
  // the file is known (more accurate than assuming
  // the whole file is audio)

  UInt64 processedPacketsCount;
  UInt64 processedPacketsSizeTotal;  // byte size of accumulated estimation packets

  double seekTime;
  double lastProgress;    // last calculated progress point
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
- (BOOL)isIdle;
- (BOOL)seekToTime:(double)newSeekTime;
- (double)calculatedBitRate;
- (BOOL)setVolume:(double)volume;
- (double)duration;
- (double)progress;

@end
