//
//  AudioStreamer.m
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

#import "AudioStreamer.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 50

#define PROXY_SYSTEM 0
#define PROXY_SOCKS  1
#define PROXY_HTTP   2

/* Default number and size of audio queue buffers */
#define kDefaultNumAQBufs 16
#define kDefaultAQDefaultBufSize 2048

#define CHECK_ERR(err, code) {                                                 \
    if (err) { [self failWithErrorCode:code]; return; }                        \
  }

#ifdef DEBUG
#define LOG(fmt, args...) NSLog(@"%s " fmt, __PRETTY_FUNCTION__, ##args)
#else
#define LOG(...)
#endif

typedef struct queued_packet {
  AudioStreamPacketDescription desc;
  struct queued_packet *next;
  char data[];
} queued_packet_t;

NSString * const ASStatusChangedNotification = @"ASStatusChangedNotification";

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
@interface AudioStreamer ()

- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags;
- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer;
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID;

- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType;

@end

/* Woohoo, actual implementation now! */
@implementation AudioStreamer

/**
 * @brief If an error occurs on the stream, then this variable is set with the
 *        code corresponding to the error
 *
 * By default this is AS_NO_ERROR.
 */
@synthesize errorCode;

/* TODO: make this go away */
@synthesize networkError;

/**
 * @brief Headers received from the remote source
 *
 * Used to determine file size, but other information may be useful as well
 */
@synthesize httpHeaders;

/**
 * @brief The remote resource that this stream is playing, this is a read-only
 *        property and cannot be changed after creation
 */
@synthesize url;

/**
 * @brief The file type of this audio stream
 *
 * This is an optional parameter. If not specified, then the file type will be
 * attempted to be inferred from the extension on the url specified. If your URL
 * doesn't conform to what AudioStreamer internally detects, then use this to
 * explicitly mark the file type. If marked, then no inferring is done.
 */
@synthesize fileType;

/**
 * @brief The number of audio buffers to have
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
 */
@synthesize bufferCnt;

/**
 * @brief The default size for each buffer allocated
 *
 * Each buffer's size is attempted to be guessed from the audio stream being
 * received. This way each buffer is tuned for the audio stream itself. If this
 * inferring of the buffer size fails, however, this is used as a fallback as
 * how large each buffer should be.
 *
 * If you find that this is being used, then it should be coordinated with
 * bufferCnt above to make sure that the audio stays responsive and slightly
 * behind the HTTP stream
 */
@synthesize bufferSize;

/**
 * @brief Flag if to infinitely buffer data
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
 * also be consumed. Depending on the situtation, this might not be that bad of
 * a problem.
 */
@synthesize bufferInfinite;

/* AudioFileStream callback when properties are available */
void MyPropertyListenerProc(void *inClientData,
                            AudioFileStreamID inAudioFileStream,
                            AudioFileStreamPropertyID inPropertyID,
                            UInt32 *ioFlags) {
  AudioStreamer* streamer = (__bridge AudioStreamer *)inClientData;
  [streamer handlePropertyChangeForFileStream:inAudioFileStream
                         fileStreamPropertyID:inPropertyID
                                      ioFlags:ioFlags];
}

/* AudioFileStream callback when packets are available */
void MyPacketsProc(void *inClientData, UInt32 inNumberBytes, UInt32
                   inNumberPackets, const void *inInputData,
                   AudioStreamPacketDescription  *inPacketDescriptions) {
  AudioStreamer* streamer = (__bridge AudioStreamer *)inClientData;
  [streamer handleAudioPackets:inInputData
                   numberBytes:inNumberBytes
                 numberPackets:inNumberPackets
            packetDescriptions:inPacketDescriptions];
}

/* AudioQueue callback notifying that a buffer is done, invoked on AudioQueue's
 * own personal threads, not the main thread */
void MyAudioQueueOutputCallback(void *inClientData, AudioQueueRef inAQ,
                                AudioQueueBufferRef inBuffer) {
  AudioStreamer* streamer = (__bridge AudioStreamer*)inClientData;
  [streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
}

/* AudioQueue callback that a property has changed, invoked on AudioQueue's own
 * personal threads like above */
void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ,
                                   AudioQueuePropertyID inID) {
  AudioStreamer* streamer = (__bridge AudioStreamer *)inUserData;
  [streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
}

/* CFReadStream callback when an event has occurred */
void ASReadStreamCallBack(CFReadStreamRef aStream, CFStreamEventType eventType,
                          void* inClientInfo) {
  AudioStreamer* streamer = (__bridge AudioStreamer *)inClientInfo;
  [streamer handleReadFromStream:aStream eventType:eventType];
}

/**
 * @brief Allocate a new audio stream with the specified url
 *
 * Thre created stream has not started playback. This gives an opportunity to
 * configure the rest of the stream as necessary. To start playback, send the
 * stream an explicit 'start' message.
 *
 * @param url the remote source of audio
 * @return the stream to configure and being playback with
 */
+ (AudioStreamer*) streamWithURL:(NSURL*)url{
  AudioStreamer *stream = [[AudioStreamer alloc] init];
  stream->url = url;
  stream->bufferCnt  = kDefaultNumAQBufs;
  stream->bufferSize = kDefaultAQDefaultBufSize;
  return stream;
}

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc {
  [self stop];
}

/**
 * @brief Set an HTTP proxy for this stream
 *
 * @param host the address/hostname of the remote host
 * @param port the port of the proxy
 */
- (void) setHTTPProxy:(NSString*)host port:(int)port {
  proxyHost = host;
  proxyPort = port;
  proxyType = PROXY_HTTP;
}

/**
 * @brief Set SOCKS proxy for this stream
 *
 * @param host the address/hostname of the remote host
 * @param port the port of the proxy
 */
- (void) setSOCKSProxy:(NSString*)host port:(int)port {
  proxyHost = host;
  proxyPort = port;
  proxyType = PROXY_SOCKS;
}

/**
 * @brief Attempt to set the volume on the audio queue
 *
 * @return YES if the volume was set, or NO if the audio queue wasn't to have
 *         the volume ready to be set. When the state for this audio streamer
 *         changes internally to have a stream, then setVolume: will work
 */
- (BOOL)setVolume: (double) volume {
  if (audioQueue != NULL) {
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, volume);
    return YES;
  }
  return NO;
}

//
// stringForErrorCode:
//
// Converts an error code to a string that can be localized or presented
// to the user.
//
// Parameters:
//    anErrorCode - the error code to convert
//
// returns the string representation of the error code
//
+ (NSString *)stringForErrorCode:(AudioStreamerErrorCode)anErrorCode {
  switch (anErrorCode) {
    case AS_NO_ERROR:
      return @"No error.";
    case AS_FILE_STREAM_GET_PROPERTY_FAILED:
      return @"File stream get property failed";
    case AS_FILE_STREAM_SET_PROPERTY_FAILED:
      return @"File stream set property failed";
    case AS_FILE_STREAM_SEEK_FAILED:
      return @"File stream seek failed";
    case AS_FILE_STREAM_PARSE_BYTES_FAILED:
      return @"Parse bytes failed";
    case AS_AUDIO_QUEUE_CREATION_FAILED:
      return @"Audio queue creation failed";
    case AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED:
      return @"Audio queue buffer allocation failed";
    case AS_AUDIO_QUEUE_ENQUEUE_FAILED:
      return @"Queueing of audio buffer failed";
    case AS_AUDIO_QUEUE_ADD_LISTENER_FAILED:
      return @"Failed to add listener to audio queue";
    case AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED:
      return @"Failed to remove listener from audio queue";
    case AS_AUDIO_QUEUE_START_FAILED:
      return @"Failed to start the audio queue";
    case AS_AUDIO_QUEUE_BUFFER_MISMATCH:
      return @"Audio queue buffer mismatch";
    case AS_FILE_STREAM_OPEN_FAILED:
      return @"Failed to open file stream";
    case AS_FILE_STREAM_CLOSE_FAILED:
      return @"Failed to close the file stream";
    case AS_AUDIO_QUEUE_DISPOSE_FAILED:
      return @"Couldn't dispose of audio queue";
    case AS_AUDIO_QUEUE_PAUSE_FAILED:
      return @"Failed to pause the audio queue";
    case AS_AUDIO_QUEUE_FLUSH_FAILED:
      return @"Failed to flush the audio queue";
    case AS_AUDIO_DATA_NOT_FOUND:
      return @"No audio data found";
    case AS_GET_AUDIO_TIME_FAILED:
      return @"Couldn't get audio time";
    case AS_NETWORK_CONNECTION_FAILED:
      return @"Network connection failure";
    case AS_AUDIO_QUEUE_STOP_FAILED:
      return @"Audio queue stop failed";
    case AS_AUDIO_STREAMER_FAILED:
      return @"Audio streamer failed";
    case AS_AUDIO_BUFFER_TOO_SMALL:
      return @"Audio buffer too small";
    default:
      break;
  }

  return @"Audio streaming failed";
}

//
// isPlaying
//
// returns YES if the audio currently playing.
//
- (BOOL)isPlaying {
  return state_ == AS_PLAYING;
}

//
// isPaused
//
// returns YES if the audio currently playing.
//
- (BOOL)isPaused {
  return state_ == AS_PAUSED;
}

//
// isWaiting
//
// returns YES if the AudioStreamer is waiting for a state transition of some
// kind.
//
- (BOOL)isWaiting {
  return state_ == AS_WAITING_FOR_DATA ||
         state_ == AS_WAITING_FOR_QUEUE_TO_START;
}

/**
 * @brief Calculates whether this streamer is done with all audio playback
 */
- (BOOL)isDone {
  return state_ == AS_DONE || state_ == AS_STOPPED;
}

/**
 * @brief Starts playback of this audio stream.
 *
 * This method can only be invoked once, and other methods will not work before
 * this method has been invoked. All properties (like proxies) must be set
 * before this method is invoked.
 *
 * @return YES if the stream was started, or NO if the stream was previously
 *         started and this had no effect.
 */
- (BOOL) start {
  if (stream != NULL) return NO;
  assert(audioQueue == NULL);
  assert(state_ == AS_INITIALIZED);
  [self openReadStream];
  timeout = [NSTimer scheduledTimerWithTimeInterval:2
                                             target:self
                                           selector:@selector(checkTimeout)
                                           userInfo:nil
                                            repeats:YES];
  return YES;
}

/**
 * @brief Seek to a specified time in the audio stream
 *
 * This can only happen once the bit rate of the stream is konwn because
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
- (BOOL)seekToTime:(double)newSeekTime {
  double bitrate;
  double duration;
  if (![self calculatedBitRate:&bitrate]) return NO;
  if (![self duration:&duration]) return NO;
  if (bitrate == 0.0 || fileLength <= 0) {
    return NO;
  }

  //
  // Calculate the byte offset for seeking
  //
  seekByteOffset = dataOffset +
    (newSeekTime / duration) * (fileLength - dataOffset);

  //
  // Attempt to leave 1 useful packet at the end of the file (although in
  // reality, this may still seek too far if the file has a long trailer).
  //
  if (seekByteOffset > fileLength - 2 * packetBufferSize) {
    seekByteOffset = fileLength - 2 * packetBufferSize;
  }

  //
  // Store the old time from the audio queue and the time that we're seeking
  // to so that we'll know the correct time progress after seeking.
  //
  seekTime = newSeekTime;

  //
  // Attempt to align the seek with a packet boundary
  //
  double packetDuration = asbd.mFramesPerPacket / asbd.mSampleRate;
  if (packetDuration > 0 && bitrate > 0) {
    UInt32 ioFlags = 0;
    SInt64 packetAlignedByteOffset;
    SInt64 seekPacket = floor(newSeekTime / packetDuration);
    err = AudioFileStreamSeek(audioFileStream, seekPacket,
                              &packetAlignedByteOffset, &ioFlags);
    if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
      seekTime -= ((seekByteOffset - dataOffset) - packetAlignedByteOffset) * 8.0 / bitrate;
      seekByteOffset = packetAlignedByteOffset + dataOffset;
    }
  }

  [self closeReadStream];

  /* Stop audio for now */
  err = AudioQueueStop(audioQueue, true);
  if (err) {
    [self failWithErrorCode:AS_AUDIO_QUEUE_STOP_FAILED];
    return NO;
  }

  /* Open a new stream with a new offset */
  return [self openReadStream];
}

/**
 * @brief Calculate the progress into the stream, in seconds
 *
 * The AudioQueue instance is polled to determine the current time into the
 * stream, and this is returned.
 *
 * @param ret a double which is filled in with the progress of the stream. The
 *        contents are undefined if NO is returned.
 * @return YES if the progress of the stream was determined, or NO if the
 *         progress could not be determined at this time.
 */
- (BOOL) progress:(double*)ret {
  double sampleRate = asbd.mSampleRate;
  if (state_ == AS_STOPPED) {
    *ret = lastProgress;
    return YES;
  }
  if (sampleRate <= 0 || (state_ != AS_PLAYING && state_ != AS_PAUSED))
    return NO;

  AudioTimeStamp queueTime;
  Boolean discontinuity;
  err = AudioQueueGetCurrentTime(audioQueue, NULL, &queueTime, &discontinuity);
  if (err) {
    return NO;
  }

  double progress = seekTime + queueTime.mSampleTime / sampleRate;
  if (progress < 0.0) {
    progress = 0.0;
  }

  lastProgress = progress;
  *ret = progress;
  return YES;
}

/**
 * @brief Calculates the bit rate of the stream
 *
 * All packets received so far contribute to the calculation of the bit rate.
 * This is used internally to determine other factors like duration and
 * progress.
 *
 * @param ret the double to fill in with the bit rate on success.
 * @return YES if the bit rate could be calculated with a high degree of
 *         certainty, or NO if it could not be.
 */
- (BOOL) calculatedBitRate:(double*)rate {
  double sampleRate     = asbd.mSampleRate;
  double packetDuration = asbd.mFramesPerPacket / sampleRate;

  if (packetDuration && processedPacketsCount > BitRateEstimationMinPackets) {
    double averagePacketByteSize = processedPacketsSizeTotal /
                                    processedPacketsCount;
    /* bits/byte x bytes/packet x packets/sec = bits/sec */
    *rate = 8 * averagePacketByteSize / packetDuration;
    return YES;
  }

  return NO;
}

/**
 * @brief Calculates the duration of the audio stream in seconds
 *
 * Uses information about the size of the file and the calculated bit rate to
 * determine the duration of the stream.
 *
 * @param ret where to fill in with the duration of the stream on success.
 * @return YES if ret contains the duration of the stream, or NO if the duration
 *         could not be determined. In the NO case, the contents of ret are
 *         undefined
 */
- (BOOL) duration:(double*)ret {
  double calculatedBitRate;
  if (![self calculatedBitRate:&calculatedBitRate]) return NO;
  if (calculatedBitRate == 0 || fileLength == 0) {
    return NO;
  }

  *ret = (fileLength - dataOffset) / (calculatedBitRate * 0.125);
  return YES;
}

/**
 * @brief Pause the audio stream if playing
 *
 * @return YES if the audio stream was paused, or NO if it was not in the
 *         AS_PLAYING state or an error occurred.
 */
- (BOOL) pause {
  if (state_ != AS_PLAYING) return NO;
  assert(audioQueue != NULL);
  err = AudioQueuePause(audioQueue);
  if (err) {
    [self failWithErrorCode:AS_AUDIO_QUEUE_PAUSE_FAILED];
    return NO;
  }
  [self setState:AS_PAUSED];
  return YES;
}

/**
 * @brief Plays the audio stream if paused
 *
 * @return YES if the audio stream entered into the AS_PLAYING state, or NO if
 *         any other error or bad state was encountered.
 */
- (BOOL) play {
  if (state_ != AS_PAUSED) return NO;
  assert(audioQueue != NULL);
  err = AudioQueueStart(audioQueue, NULL);
  if (err) {
    [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
    return NO;
  }
  [self setState:AS_PLAYING];
  return YES;
}

/**
 * @brief Stop all streams, cleaning up resources and preventing all further
 *        events from ocurring.
 *
 * This method may be invoked at any time from any point of the audio stream as
 * a signal of error happening. This method sets the state to AS_STOPPED if it
 * isn't already AS_STOPPED or AS_DONE.
 */
- (void) stop {
  if (![self isDone]) {
    [self setState:AS_STOPPED];
  }

  [timeout invalidate];
  timeout = nil;

  /* Clean up our streams */
  [self closeReadStream];
  if (audioFileStream) {
    err = AudioFileStreamClose(audioFileStream);
    assert(!err);
    audioFileStream = nil;
  }
  if (audioQueue) {
    AudioQueueStop(audioQueue, true);
    err = AudioQueueDispose(audioQueue, true);
    assert(!err);
    audioQueue = nil;
  }
  if (buffers != NULL) {
    free(buffers);
    buffers = NULL;
  }
  if (inuse != NULL) {
    free(inuse);
    inuse = NULL;
  }

  httpHeaders      = nil;
  bytesFilled      = 0;
  packetsFilled    = 0;
  seekByteOffset   = 0;
  packetBufferSize = 0;
}

/* Internal Functions ======================================================= */

//
// failWithErrorCode:
//
// Sets the playback state to failed and logs the error.
//
// Parameters:
//    anErrorCode - the error condition
//
- (void)failWithErrorCode:(AudioStreamerErrorCode)anErrorCode {
  // Only set the error once.
  if (errorCode != AS_NO_ERROR) {
    assert(state_ == AS_STOPPED);
    return;
  }
  /* Attempt to save our last point of progress */
  [self progress:&lastProgress];

  LOG(@"got an error: %@", [AudioStreamer stringForErrorCode:anErrorCode]);
  errorCode = anErrorCode;

  [self stop];
}

- (void)setState:(AudioStreamerState)aStatus {
  LOG(@"transitioning to state:%d", aStatus);

  if (state_ == aStatus) return;
  state_ = aStatus;

  [[NSNotificationCenter defaultCenter]
        postNotificationName:ASStatusChangedNotification
                      object:self];
}

/**
 * @brief Check the stream for a timeout, and trigger one if this is a timeout
 *        situation
 */
- (void) checkTimeout {
  /* Ignore if we're in the paused state */
  if (state_ == AS_PAUSED) return;
  /* If the read stream has been unscheduled and not rescheduled, then this tick
     is irrelevant because we're not trying to read data anyway */
  if (unscheduled && !rescheduled) return;
  /* If the read stream was unscheduled and then rescheduled, then we still
     discard this sample (not enough of it was known to be in the "scheduled
     state"), but we clear flags so we might process the next sample */
  if (rescheduled && unscheduled) {
    unscheduled = NO;
    rescheduled = NO;
    return;
  }

  /* events happened? no timeout. */
  if (events > 0) {
    events = 0;
    return;
  }

  networkError = [NSError errorWithDomain:@"Timed out" code:1 userInfo:nil];
  [self failWithErrorCode:AS_TIMED_OUT];
}

//
// hintForFileExtension:
//
// Generates a first guess for the file type based on the file's extension
//
// Parameters:
//    fileExtension - the file extension
//
// returns a file type hint that can be passed to the AudioFileStream
//
+ (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension {
  AudioFileTypeID fileTypeHint = kAudioFileAAC_ADTSType;
  if ([fileExtension isEqual:@"mp3"]) {
    fileTypeHint = kAudioFileMP3Type;
  } else if ([fileExtension isEqual:@"wav"]) {
    fileTypeHint = kAudioFileWAVEType;
  } else if ([fileExtension isEqual:@"aifc"]) {
    fileTypeHint = kAudioFileAIFCType;
  } else if ([fileExtension isEqual:@"aiff"]) {
    fileTypeHint = kAudioFileAIFFType;
  } else if ([fileExtension isEqual:@"m4a"]) {
    fileTypeHint = kAudioFileM4AType;
  } else if ([fileExtension isEqual:@"mp4"]) {
    fileTypeHint = kAudioFileMPEG4Type;
  } else if ([fileExtension isEqual:@"caf"]) {
    fileTypeHint = kAudioFileCAFType;
  } else if ([fileExtension isEqual:@"aac"]) {
    fileTypeHint = kAudioFileAAC_ADTSType;
  }
  return fileTypeHint;
}

/**
 * @brief Creates a new stream for reading audio data
 *
 * The stream is currently only compatible with remote HTTP sources. The stream
 * opened could possibly be seeked into the middle of the file, or have other
 * things like proxies attached to it.
 *
 * @return YES if the stream was opened, or NO if it failed to open
 */
- (BOOL)openReadStream {
  NSAssert(stream == NULL, @"Download stream already initialized");

  /* Create our GET request */
  CFHTTPMessageRef message =
      CFHTTPMessageCreateRequest(NULL,
                                 CFSTR("GET"),
                                 (__bridge CFURLRef) url,
                                 kCFHTTPVersion1_1);

  /* When seeking to a time within the stream, we both already know the file
     length and the seekByteOffset will be set to know what to send to the
     remote server */
  if (fileLength > 0 && seekByteOffset > 0) {
   NSString *str = [NSString stringWithFormat:@"bytes=%ld-%ld",
                                              seekByteOffset, fileLength];
    CFHTTPMessageSetHeaderFieldValue(message,
                                     CFSTR("Range"),
                                     (__bridge CFStringRef) str);
    discontinuous = YES;
  }

  stream = CFReadStreamCreateForHTTPRequest(NULL, message);
  CFRelease(message);

  /* Follow redirection codes by default */
  if (!CFReadStreamSetProperty(stream,
                               kCFStreamPropertyHTTPShouldAutoredirect,
                               kCFBooleanTrue)) {
    [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
    return NO;
  }

  /* Deal with proxies */
  switch (proxyType) {
    case PROXY_HTTP: {
      CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
          proxyHost, kCFStreamPropertyHTTPProxyHost,
          [NSNumber numberWithInt:proxyPort], kCFStreamPropertyHTTPProxyPort,
          nil];
      CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy,
                              proxySettings);
      break;
    }
    case PROXY_SOCKS: {
      CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
          proxyHost, kCFStreamPropertySOCKSProxyHost,
          [NSNumber numberWithInt:proxyPort], kCFStreamPropertySOCKSProxyPort,
          nil];
      CFReadStreamSetProperty(stream, kCFStreamPropertySOCKSProxy,
                              proxySettings);
      break;
    }
    default:
    case PROXY_SYSTEM: {
      CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
      CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy, proxySettings);
      CFRelease(proxySettings);
      break;
    }
  }

  /* handle SSL connections */
  if ([[url absoluteString] rangeOfString:@"https"].location == 0) {
    NSDictionary *sslSettings =
    [NSDictionary dictionaryWithObjectsAndKeys:
     (NSString*)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsExpiredCertificates,
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsExpiredRoots,
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsAnyRoot,
     [NSNumber numberWithBool:YES], kCFStreamSSLValidatesCertificateChain,
     [NSNull null], kCFStreamSSLPeerName,
     nil];

    CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings,
                            (__bridge CFDictionaryRef) sslSettings);
  }

  [self setState:AS_WAITING_FOR_DATA];

  if (!CFReadStreamOpen(stream)) {
    CFRelease(stream);
    [self failWithErrorCode:AS_FILE_STREAM_OPEN_FAILED];
    return NO;
  }

  /* Set the callback to receive a few events, and then we're ready to
     schedule and go */
  CFStreamClientContext context = {0, (__bridge void*) self, NULL, NULL, NULL};
  CFReadStreamSetClient(stream,
                        kCFStreamEventHasBytesAvailable |
                          kCFStreamEventErrorOccurred |
                          kCFStreamEventEndEncountered,
                        ASReadStreamCallBack,
                        &context);
  CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),
                                  kCFRunLoopCommonModes);

  return YES;
}

//
// handleReadFromStream:eventType:
//
// Reads data from the network file stream into the AudioFileStream
//
// Parameters:
//    aStream - the network file stream
//    eventType - the event which triggered this method
//
- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType {
  assert(aStream == stream);
  assert(!waitingOnBuffer || bufferInfinite);
  events++;

  switch (eventType) {
    case kCFStreamEventErrorOccurred:
      LOG(@"error");
      networkError = (__bridge_transfer NSError*) CFReadStreamCopyError(aStream);
      [self failWithErrorCode:AS_NETWORK_CONNECTION_FAILED];
      return;

    case kCFStreamEventEndEncountered:
      LOG(@"end");
      [timeout invalidate];
      timeout = nil;

      /* Flush out extra data if necessary */
      if (bytesFilled) {
        /* Disregard return value because we're at the end of the stream anyway
           so there's no bother in pausing it */
        if ([self enqueueBuffer] < 0) return;
      }

      /* If we never received any packets, then we fail */
      if (state_ == AS_WAITING_FOR_DATA) {
        [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
      }
      return;

    default:
      return;

    case kCFStreamEventHasBytesAvailable:
      break;
  }
  LOG(@"data");

  /* Read off the HTTP headers into our own class if we haven't done so */
  if (!httpHeaders) {
    CFTypeRef message =
        CFReadStreamCopyProperty(stream, kCFStreamPropertyHTTPResponseHeader);
    httpHeaders = (__bridge_transfer NSDictionary *)
        CFHTTPMessageCopyAllHeaderFields((CFHTTPMessageRef) message);
    CFRelease(message);

    //
    // Only read the content length if we seeked to time zero, otherwise
    // we only have a subset of the total bytes.
    //
    if (seekByteOffset == 0) {
      fileLength = [[httpHeaders objectForKey:@"Content-Length"] integerValue];
    }
  }

  /* If we haven't yet opened up a file stream, then do so now */
  if (!audioFileStream) {
    /* If a file type wasn't specified, we have to guess */
    AudioFileTypeID fileTypeHint = fileType != 0 ? fileType :
      [AudioStreamer hintForFileExtension:[[url path] pathExtension]];

    // create an audio file stream parser
    err = AudioFileStreamOpen((__bridge void*) self, MyPropertyListenerProc,
                              MyPacketsProc, fileTypeHint, &audioFileStream);
    CHECK_ERR(err, AS_FILE_STREAM_OPEN_FAILED);
  }

  UInt8 bytes[2048];
  CFIndex length;
  while (state_ != AS_STOPPED && CFReadStreamHasBytesAvailable(stream)) {
    length = CFReadStreamRead(stream, bytes, sizeof(bytes));

    if (length < 0) {
      [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
      return;
    } else if (length == 0) {
      return;
    }

    if (discontinuous) {
      err = AudioFileStreamParseBytes(audioFileStream, length, bytes,
                                      kAudioFileStreamParseFlag_Discontinuity);
    } else {
      err = AudioFileStreamParseBytes(audioFileStream, length, bytes, 0);
    }
    CHECK_ERR(err, AS_FILE_STREAM_PARSE_BYTES_FAILED);
  }
}

//
// enqueueBuffer
//
// Called from MyPacketsProc and connectionDidFinishLoading to pass filled audio
// bufffers (filled by MyPacketsProc) to the AudioQueue for playback. This
// function does not return until a buffer is idle for further filling or
// the AudioQueue is stopped.
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// CBR functionality added.
//
- (int) enqueueBuffer {
  assert(stream != NULL);

  assert(!inuse[fillBufferIndex]);
  inuse[fillBufferIndex] = true;    // set in use flag
  buffersUsed++;

  // enqueue buffer
  AudioQueueBufferRef fillBuf = buffers[fillBufferIndex];
  fillBuf->mAudioDataByteSize = bytesFilled;

  assert(packetsFilled > 0);
  err = AudioQueueEnqueueBuffer(audioQueue, fillBuf, packetsFilled,
                                packetDescs);
  if (err) {
    [self failWithErrorCode:AS_AUDIO_QUEUE_ENQUEUE_FAILED];
    return -1;
  }
  LOG(@"committed buffer %d", fillBufferIndex);

  if (state_ == AS_WAITING_FOR_DATA) {
    /* Once we have a small amount of queued data, then we can go ahead and
     * start the audio queue and the file stream should remain ahead of it */
    if (bufferCnt < 3 || buffersUsed > 2) {
      err = AudioQueueStart(audioQueue, NULL);
      if (err) {
        [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
        return -1;
      }
      [self setState:AS_WAITING_FOR_QUEUE_TO_START];
    }
  }

  /* move on to the next buffer and wait for it to be in use */
  if (++fillBufferIndex >= bufferCnt) fillBufferIndex = 0;
  bytesFilled   = 0;    // reset bytes filled
  packetsFilled = 0;    // reset packets filled

  /* If we have no more queued data, and the stream has reached its end, then
     we're not going to be enqueueing any more buffers to the audio stream. In
     this case flush it out and asynchronously stop it */
  if (queued_head == NULL &&
      CFReadStreamGetStatus(stream) == kCFStreamStatusAtEnd) {
    err = AudioQueueFlush(audioQueue);
    if (err) {
      [self failWithErrorCode:AS_AUDIO_QUEUE_FLUSH_FAILED];
      return -1;
    }
    err = AudioQueueStop(audioQueue, false);
    if (err) {
      [self failWithErrorCode:AS_AUDIO_QUEUE_STOP_FAILED];
      return -1;
    }
  }

  /* The inuse array is also managed by a separate AudioQueue internal thread,
     so we need to synchronize around unscheduling the read stream to ensure
     that our state is always coherent */
  @synchronized(self) {
    if (inuse[fillBufferIndex]) {
      LOG(@"waiting for buffer %d", fillBufferIndex);
      if (!bufferInfinite) {
        CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(),
                                          kCFRunLoopCommonModes);
        /* Make sure we don't have ourselves marked as rescheduled */
        unscheduled = YES;
        rescheduled = NO;
      }
      waitingOnBuffer = true;
      return 0;

    }
  }
  return 1;
}

//
// createQueue
//
// Method to create the AudioQueue from the parameters gathered by the
// AudioFileStream.
//
// Creation is deferred to the handling of the first audio packet (although
// it could be handled any time after kAudioFileStreamProperty_ReadyToProducePackets
// is true).
//
- (void)createQueue {
  assert(audioQueue == NULL);

  // create the audio queue
  err = AudioQueueNewOutput(&asbd, MyAudioQueueOutputCallback,
                            (__bridge void*) self, NULL, NULL, 0, &audioQueue);
  CHECK_ERR(err, AS_AUDIO_QUEUE_CREATION_FAILED);

  // start the queue if it has not been started already
  // listen to the "isRunning" property
  err = AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning,
                                      MyAudioQueueIsRunningCallback,
                                      (__bridge void*) self);
  CHECK_ERR(err, AS_AUDIO_QUEUE_ADD_LISTENER_FAILED);

  /* Try to determine the packet size, eventually falling back to some
     reasonable default of a size */
  UInt32 sizeOfUInt32 = sizeof(UInt32);
  err = AudioFileStreamGetProperty(audioFileStream,
          kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32,
          &packetBufferSize);

  if (err || packetBufferSize == 0) {
    err = AudioFileStreamGetProperty(audioFileStream,
            kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32,
            &packetBufferSize);
    if (err || packetBufferSize == 0) {
      // No packet size available, just use the default
      packetBufferSize = bufferSize;
    }
  }

  // allocate audio queue buffers
  buffers = malloc(bufferCnt * sizeof(buffers[0]));
  CHECK_ERR(buffers == NULL, AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED);
  inuse = calloc(bufferCnt, sizeof(inuse[0]));
  CHECK_ERR(inuse == NULL, AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED);
  for (unsigned int i = 0; i < bufferCnt; ++i) {
    err = AudioQueueAllocateBuffer(audioQueue, packetBufferSize,
                                   &buffers[i]);
    CHECK_ERR(err, AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED);
  }

  /* Some audio formats have a "magic cookie" which needs to be transferred from
     the file stream to the audio queue. If any of this fails it's "OK" because
     the stream either doesn't have a magic or error will propogate later */

  // get the cookie size
  UInt32 cookieSize;
  Boolean writable;
  OSStatus ignorableError;
  ignorableError = AudioFileStreamGetPropertyInfo(audioFileStream,
                     kAudioFileStreamProperty_MagicCookieData, &cookieSize,
                     &writable);
  if (ignorableError) {
    return;
  }

  // get the cookie data
  void *cookieData = calloc(1, cookieSize);
  if (cookieData == NULL) return;
  ignorableError = AudioFileStreamGetProperty(audioFileStream,
                     kAudioFileStreamProperty_MagicCookieData, &cookieSize,
                     cookieData);
  if (ignorableError) {
    free(cookieData);
    return;
  }

  // set the cookie on the queue. Don't worry if it fails, all we'd to is return
  // anyway
  AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookieData,
                        cookieSize);
  free(cookieData);
}

//
// handlePropertyChangeForFileStream:fileStreamPropertyID:ioFlags:
//
// Object method which handles implementation of MyPropertyListenerProc
//
// Parameters:
//    inAudioFileStream - should be the same as self->audioFileStream
//    inPropertyID - the property that changed
//    ioFlags - the ioFlags passed in
//
- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags {
  assert(inAudioFileStream == audioFileStream);

  switch (inPropertyID) {
    case kAudioFileStreamProperty_ReadyToProducePackets:
      LOG(@"ready for packets");
      discontinuous = true;
      break;

    case kAudioFileStreamProperty_DataOffset: {
      SInt64 offset;
      UInt32 offsetSize = sizeof(offset);
      err = AudioFileStreamGetProperty(inAudioFileStream,
              kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
      CHECK_ERR(err, AS_FILE_STREAM_GET_PROPERTY_FAILED);
      dataOffset = offset;

      if (audioDataByteCount) {
        fileLength = dataOffset + audioDataByteCount;
      }
      LOG(@"have data offset: %llx", dataOffset);
      break;
    }

    case kAudioFileStreamProperty_AudioDataByteCount: {
      UInt32 byteCountSize = sizeof(UInt64);
      err = AudioFileStreamGetProperty(inAudioFileStream,
              kAudioFileStreamProperty_AudioDataByteCount,
              &byteCountSize, &audioDataByteCount);
      CHECK_ERR(err, AS_FILE_STREAM_GET_PROPERTY_FAILED);
      fileLength = dataOffset + audioDataByteCount;
      LOG(@"have byte count: %llx", audioDataByteCount);
      break;
    }

    case kAudioFileStreamProperty_DataFormat: {
      /* If we seeked, don't re-read the data */
      if (asbd.mSampleRate == 0) {
        UInt32 asbdSize = sizeof(asbd);

        err = AudioFileStreamGetProperty(inAudioFileStream,
                kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
        CHECK_ERR(err, AS_FILE_STREAM_GET_PROPERTY_FAILED);
      }
      LOG(@"have data format");
      break;
    }

    /* if AAC or SBR needs to be supported, fix this */
    /*case kAudioFileStreamProperty_FormatList: {
      Boolean outWriteable;
      UInt32 formatListSize;
      err = AudioFileStreamGetPropertyInfo(inAudioFileStream,
              kAudioFileStreamProperty_FormatList,
              &formatListSize, &outWriteable);
      CHECK_ERR(err, AS_FILE_STREAM_GET_PROPERTY_FAILED);

      AudioFormatListItem *formatList = malloc(formatListSize);
      CHECK_ERR(formatList == NULL, AS_FILE_STREAM_GET_PROPERTY_FAILED);
      err = AudioFileStreamGetProperty(inAudioFileStream,
              kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
      CHECK_ERR(err, AS_FILE_STREAM_GET_PROPERTY_FAILED);

      for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize;
           i += sizeof(AudioFormatListItem)) {
        AudioStreamBasicDescription pasbd = formatList[i].mASBD;

        if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE)
        {
          break;
        }
      }
      free(formatList);
      break;
    }*/
  }
}

//
// handleAudioPackets:numberBytes:numberPackets:packetDescriptions:
//
// Object method which handles the implementation of MyPacketsProc
//
// Parameters:
//    inInputData - the packet data
//    inNumberBytes - byte size of the data
//    inNumberPackets - number of packets in the data
//    inPacketDescriptions - packet descriptions
//
- (void)handleAudioPackets:(const void*)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription*)inPacketDescriptions {
  if (state_ == AS_STOPPED) return;
  // we have successfully read the first packests from the audio stream, so
  // clear the "discontinuous" flag
  if (discontinuous) {
    discontinuous = false;
  }

  if (!audioQueue) {
    assert(!waitingOnBuffer);
    [self createQueue];
  }
  assert(inPacketDescriptions != NULL);

  /* Place each packet into a buffer and then send each buffer into the audio
     queue */
  UInt32 i;
  for (i = 0; i < inNumberPackets && !waitingOnBuffer && queued_head == NULL; i++) {
    AudioStreamPacketDescription *desc = &inPacketDescriptions[i];
    int ret = [self handlePacket:(inInputData + desc->mStartOffset)
                            desc:desc];
    CHECK_ERR(ret < 0, AS_AUDIO_QUEUE_ENQUEUE_FAILED);
    if (!ret) break;
  }
  if (i == inNumberPackets) return;

  for (; i < inNumberPackets; i++) {
    /* Allocate the packet */
    UInt32 size = inPacketDescriptions[i].mDataByteSize;
    queued_packet_t *packet = malloc(sizeof(queued_packet_t) + size);
    CHECK_ERR(packet == NULL, AS_AUDIO_QUEUE_ENQUEUE_FAILED);

    /* Prepare the packet */
    packet->next = NULL;
    packet->desc = inPacketDescriptions[i];
    packet->desc.mStartOffset = 0;
    memcpy(packet->data, inInputData + inPacketDescriptions[i].mStartOffset,
           size);

    if (queued_head == NULL) {
      queued_head = queued_tail = packet;
    } else {
      queued_tail->next = packet;
      queued_tail = packet;
    }
  }
}

- (int) handlePacket:(const void*)data
                desc:(AudioStreamPacketDescription*)desc{
  assert(audioQueue != NULL);
  UInt64 packetSize = desc->mDataByteSize;

  /* This shouldn't happen because most of the time we read the packet buffer
     size from the file stream, but if we restored to guessing it we could
     come up too small here */
  if (packetSize > packetBufferSize) return -1;

  // if the space remaining in the buffer is not enough for this packet, then
  // enqueue the buffer and wait for another to become available.
  if (packetBufferSize - bytesFilled < packetSize) {
    int hasFreeBuffer = [self enqueueBuffer];
    if (hasFreeBuffer <= 0) {
      return hasFreeBuffer;
    }
    assert(bytesFilled == 0);
    assert(packetBufferSize >= packetSize);
  }

  /* global statistics */
  processedPacketsSizeTotal += packetSize;
  processedPacketsCount++;

  // copy data to the audio queue buffer
  AudioQueueBufferRef buf = buffers[fillBufferIndex];
  memcpy(buf->mAudioData + bytesFilled, data, packetSize);

  // fill out packet description to pass to enqueue() later on
  packetDescs[packetsFilled] = *desc;
  // Make sure the offset is relative to the start of the audio buffer
  packetDescs[packetsFilled].mStartOffset = bytesFilled;
  // keep track of bytes filled and packets filled
  bytesFilled += packetSize;
  packetsFilled++;

  /* If filled our buffer with packets, then commit it to the system */
  if (packetsFilled >= kAQMaxPacketDescs) return [self enqueueBuffer];
  return 1;
}

/**
 * @brief Internal helper for sending cached packets to the audio queue
 *
 * This method is enqueued for delivery when an audio buffer is freed
 */
- (void) enqueueCachedData {
  if (state_ == AS_STOPPED) return;
  assert(!waitingOnBuffer);
  assert(!inuse[fillBufferIndex]);
  assert(stream != NULL);
  LOG(@"processing some cached data");

  /* Queue up as many packets as possible into the buffers */
  queued_packet_t *cur = queued_head;
  while (cur != NULL) {
    int ret = [self handlePacket:cur->data desc:&cur->desc];
    CHECK_ERR(ret < 0, AS_AUDIO_QUEUE_ENQUEUE_FAILED);
    if (ret == 0) break;
    queued_packet_t *next = cur->next;
    free(cur);
    cur = next;
  }
  queued_head = cur;

  /* If we finished queueing all our saved packets, we can re-schedule the
   * stream to run */
  if (cur == NULL) {
    queued_tail = NULL;
    rescheduled = YES;
    if (!bufferInfinite) {
      CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),
                                      kCFRunLoopCommonModes);
    }
  }
}

//
// handleBufferCompleteForQueue:buffer:
//
// Handles the buffer completetion notification from the audio queue
//
// Parameters:
//    inAQ - the queue
//    inBuffer - the buffer
//
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer {
  /* we're only registered for one audio queue... */
  assert(inAQ == audioQueue);
  /* Sanity check to make sure we're on one of the AudioQueue's internal threads
     for processing data */
  assert([NSThread currentThread] != [NSThread mainThread]);

  /* Figure out which buffer just became free, and it had better damn well be
     one of our own buffers */
  UInt32 idx;
  for (idx = 0; idx < bufferCnt; idx++) {
    if (buffers[idx] == inBuffer) break;
  }
  assert(idx >= 0 && idx < bufferCnt);
  assert(inuse[idx]);

  LOG(@"buffer %d finished", idx);

  // signal waiting thread that the buffer is free.
  @synchronized(self) {
    inuse[idx] = false;
    buffersUsed--;
    if (buffersUsed == 0 && queued_head == NULL && stream != nil &&
        CFReadStreamGetStatus(stream) == kCFStreamStatusAtEnd) {
      assert(!waitingOnBuffer);
      [self performSelectorOnMainThread:@selector(setStateObj:)
                             withObject:[NSNumber numberWithInt:AS_DONE]
                          waitUntilDone:NO];
    } else if (waitingOnBuffer) {
      waitingOnBuffer = false;
      [self performSelectorOnMainThread:@selector(enqueueCachedData)
                             withObject:nil
                          waitUntilDone:NO];
    }
  }
}

- (void) setStateObj:(NSNumber*) num {
  [self setState:[num intValue]];
}

//
// handlePropertyChangeForQueue:propertyID:
//
// Implementation for MyAudioQueueIsRunningCallback
//
// Parameters:
//    inAQ - the audio queue
//    inID - the property ID
//
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID {
  /* Sanity check to make sure we're on one of the AudioQueue's internal threads
     for processing data */
  assert([NSThread currentThread] != [NSThread mainThread]);
  /* We only asked for one property, so the audio queue had better damn well
     only tell us about this property */
  assert(inID == kAudioQueueProperty_IsRunning);

  [self performSelectorOnMainThread:@selector(queueRunningChanged)
                         withObject:nil
                      waitUntilDone:NO];
}

- (void) queueRunningChanged {
  if (state_ == AS_WAITING_FOR_QUEUE_TO_START) {
    [self setState:AS_PLAYING];
  }
}

/**
 * @brief Closes the read stream and frees all queued data
 */
- (void) closeReadStream {
  if (waitingOnBuffer) waitingOnBuffer = FALSE;
  queued_packet_t *cur = queued_head;
  while (cur != NULL) {
    queued_packet_t *tmp = cur->next;
    free(cur);
    cur = tmp;
  }
  queued_head = queued_tail = NULL;

  if (stream) {
    CFReadStreamClose(stream);
    CFRelease(stream);
    stream = nil;
  }
}

@end
