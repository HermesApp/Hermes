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

extern NSString * const ASStatusChangedNotification;

struct queued_packet;

/* Compact description of what the AudioStreamer can do, for a detailed
   description of all methods, see the source, AudioStreamer.m */
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
  size_t packetsFilled;         /* number of valid entries in packetDescs */
  size_t bytesFilled;           /* bytes in use in the pending buffer */
  unsigned int fillBufferIndex; /* index of the pending buffer */
  BOOL *inuse;                  /* which buffers have yet to be processed */
  UInt32 buffersUsed;           /* Number of buffers in use */

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
  UInt64 seekByteOffset;     /* position with the file to seek */
  double seekTime;
  double lastProgress;       /* last calculated progress point */
  UInt64 processedPacketsCount;     /* bit rate calculation utility */
  UInt64 processedPacketsSizeTotal; /* helps calculate the bit rate */
}

@property AudioStreamerErrorCode errorCode;
@property (readonly) NSDictionary *httpHeaders;
@property (readonly) NSError *networkError;
@property (readonly) NSURL *url;
@property (readwrite) UInt32 bufferCnt;
@property (readwrite) UInt32 bufferSize;
@property (readwrite) AudioFileTypeID fileType;
@property (readwrite) BOOL bufferInfinite;

+ (NSString*) stringForErrorCode:(AudioStreamerErrorCode)anErrorCode;

/* Creating an audio stream and managing properties before starting */
+ (AudioStreamer*) streamWithURL:(NSURL*)url;
- (void) setHTTPProxy:(NSString*)host port:(int)port;
- (void) setSOCKSProxy:(NSString*)host port:(int)port;

/* Management of the stream and testing state */
- (BOOL) start;
- (void) stop;
- (BOOL) pause;
- (BOOL) play;
- (BOOL) isPlaying;
- (BOOL) isPaused;
- (BOOL) isWaiting;
- (BOOL) isDone;

/* Calculated properties and modifying the stream (all can fail) */
- (BOOL) seekToTime:(double)newSeekTime;
- (BOOL) calculatedBitRate:(double*)ret;
- (BOOL) setVolume:(double)volume;
- (BOOL) duration:(double*)ret;
- (BOOL) progress:(double*)ret;

@end
