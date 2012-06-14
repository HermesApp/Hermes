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
#import "URLConnection.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 50

#define CHECK_ERR(err, code) {                                                 \
    if (err) { [self failWithErrorCode:code]; return; }                        \
  }

#define LOG(fmt, args...) NSLog(@"%s " fmt, __PRETTY_FUNCTION__, ##args)
//#define LOG(...)

typedef struct queued_packet {
  AudioStreamPacketDescription desc;
  struct queued_packet *next;
  char data[];
} queued_packet_t;

NSString * const ASStatusChangedNotification = @"ASStatusChangedNotification";

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

- (int)enqueueBuffer;
- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType;

@end

//
// MyPropertyListenerProc
//
// Receives notification when the AudioFileStream has audio packets to be
// played. In response, this function creates the AudioQueue, getting it
// ready to begin playback (playback won't begin until audio packets are
// sent to the queue in MyEnqueueBuffer).
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// kAudioQueueProperty_IsRunning listening added.
//
void MyPropertyListenerProc(void *inClientData,
                            AudioFileStreamID inAudioFileStream,
                            AudioFileStreamPropertyID inPropertyID,
                            UInt32 *ioFlags)
{
  // this is called by audio file stream when it finds property values
  AudioStreamer* streamer = (__bridge AudioStreamer *)inClientData;
  [streamer
   handlePropertyChangeForFileStream:inAudioFileStream
   fileStreamPropertyID:inPropertyID
   ioFlags:ioFlags];
}

//
// MyPacketsProc
//
// When the AudioStream has packets to be played, this function gets an
// idle audio buffer and copies the audio packets into it. The calls to
// MyEnqueueBuffer won't return until there are buffers available (or the
// playback has been stopped).
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// CBR functionality added.
//
void MyPacketsProc(        void *              inClientData,
                   UInt32              inNumberBytes,
                   UInt32              inNumberPackets,
                   const void *          inInputData,
                   AudioStreamPacketDescription  *inPacketDescriptions)
{
  // this is called by audio file stream when it finds packets of audio
  AudioStreamer* streamer = (__bridge AudioStreamer *)inClientData;
  [streamer
   handleAudioPackets:inInputData
   numberBytes:inNumberBytes
   numberPackets:inNumberPackets
   packetDescriptions:inPacketDescriptions];
}

//
// MyAudioQueueOutputCallback
//
// Called from the AudioQueue when playback of specific buffers completes. This
// function signals from the AudioQueue thread to the AudioStream thread that
// the buffer is idle and available for copying data.
//
// This function is unchanged from Apple's example in AudioFileStreamExample.
//
void MyAudioQueueOutputCallback(  void*          inClientData,
                                AudioQueueRef      inAQ,
                                AudioQueueBufferRef    inBuffer)
{
  // this is called by the audio queue when it has finished decoding our data.
  // The buffer is now free to be reused.
  AudioStreamer* streamer = (__bridge AudioStreamer*)inClientData;
  [streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
}

//
// MyAudioQueueIsRunningCallback
//
// Called from the AudioQueue when playback is started or stopped. This
// information is used to toggle the observable "isPlaying" property and
// set the "finished" flag.
//
void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
  AudioStreamer* streamer = (__bridge AudioStreamer *)inUserData;
  [streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
}

//
// ReadStreamCallBack
//
// This is the callback for the CFReadStream from the network connection. This
// is where all network data is passed to the AudioFileStream.
//
// Invoked when an error occurs, the stream ends or we have data to read.
//
void ASReadStreamCallBack
(
 CFReadStreamRef aStream,
 CFStreamEventType eventType,
 void* inClientInfo
 )
{
  AudioStreamer* streamer = (__bridge AudioStreamer *)inClientInfo;
  [streamer handleReadFromStream:aStream eventType:eventType];
}

@implementation AudioStreamer

@synthesize errorCode;
@synthesize networkError;
@synthesize state = state_;
@synthesize httpHeaders;

//
// initWithURL
//
// Init method for the object.
//
- (id)initWithURL:(NSURL *)aURL {
  url = aURL;
  LOG(@"created with %@", aURL);
  return self;
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

  LOG(@"got an error: %@", [AudioStreamer stringForErrorCode:anErrorCode]);
  errorCode = anErrorCode;

  [self stop];
}

//
// mainThreadStateNotification
//
// Method invoked on main thread to send notifications to the main thread's
// notification center.
//
- (void)mainThreadStateNotification {
}

- (void)setState:(AudioStreamerState)aStatus {
  LOG(@"transitioning to state:%d", aStatus);
  LOG("%d %d", AS_DONE, AS_STOPPED);

  if (state_ == aStatus) return;
  state_ = aStatus;

  [[NSNotificationCenter defaultCenter]
        postNotificationName:ASStatusChangedNotification
                      object:self];
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

  [URLConnection setHermesProxy:stream];

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

/**
 * @brief Starts playback of this audio stream.
 *
 * This method can only be invoked once, and other methods will not work before
 * this method has been invoked
 */
- (void) start {
  assert(audioQueue == NULL);
  assert(stream == NULL);
  assert(state_ == AS_INITIALIZED);
  [self openReadStream];
  timeout = [NSTimer scheduledTimerWithTimeInterval:2
                                             target:self
                                           selector:@selector(checkTimeout)
                                           userInfo:nil
                                            repeats:YES];
}

- (void) checkTimeout {
  if (unscheduled && !rescheduled) return;
  if (rescheduled && unscheduled) {
    unscheduled = NO;
    rescheduled = NO;
    return;
  }

  if (events > 0) {
    events = 0;
    return;
  }

  networkError = [NSError errorWithDomain:@"Timed out" code:1 userInfo:nil];
  [self failWithErrorCode:AS_TIMED_OUT];
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
  if ([self calculatedBitRate] == 0.0 || fileLength <= 0) {
    return NO;
  }

  //
  // Calculate the byte offset for seeking
  //
  seekByteOffset = dataOffset +
    (newSeekTime / self.duration) * (fileLength - dataOffset);

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
  double calculatedBitRate = [self calculatedBitRate];
  double packetDuration = asbd.mFramesPerPacket / asbd.mSampleRate;
  if (packetDuration > 0 && calculatedBitRate > 0) {
    UInt32 ioFlags = 0;
    SInt64 packetAlignedByteOffset;
    SInt64 seekPacket = floor(newSeekTime / packetDuration);
    err = AudioFileStreamSeek(audioFileStream, seekPacket,
                              &packetAlignedByteOffset, &ioFlags);
    if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
      seekTime -= ((seekByteOffset - dataOffset) - packetAlignedByteOffset) * 8.0 / calculatedBitRate;
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

//
// progress
//
// returns the current playback progress. Will return zero if sampleRate has
// not yet been detected.
//
- (double)progress {
  double sampleRate = asbd.mSampleRate;
  if (sampleRate <= 0 || (state_ != AS_PLAYING && state_ != AS_PAUSED))
    return lastProgress;

  AudioTimeStamp queueTime;
  Boolean discontinuity;
  err = AudioQueueGetCurrentTime(audioQueue, NULL, &queueTime, &discontinuity);
  if (err) {
    return lastProgress;
  }

  double progress = seekTime + queueTime.mSampleTime / sampleRate;
  if (progress < 0.0) {
    progress = 0.0;
  }

  lastProgress = progress;
  return progress;
}

//
// calculatedBitRate
//
// returns the bit rate, if known. Uses packet duration times running bits per
//   packet if available, otherwise it returns the nominal bitrate. Will return
//   zero if no useful option available.
//
- (double)calculatedBitRate {
  double sampleRate     = asbd.mSampleRate;
  double packetDuration = asbd.mFramesPerPacket / sampleRate;

  if (packetDuration && processedPacketsCount > BitRateEstimationMinPackets) {
    double averagePacketByteSize = processedPacketsSizeTotal /
                                    processedPacketsCount;
    /* bits/byte x bytes/packet x packets/sec = bits/sec */
    return 8 * averagePacketByteSize / packetDuration;
  }

  return 0;
}

//
// duration
//
// Calculates the duration of available audio from the bitRate and fileLength.
//
// returns the calculated duration in seconds.
//
- (double)duration {
  double calculatedBitRate = [self calculatedBitRate];

  if (calculatedBitRate == 0 || fileLength == 0) {
    return 0.0;
  }

  return (fileLength - dataOffset) / (calculatedBitRate * 0.125);
}

//
// pause
//
// Pause the stream if it's playing
//
- (void)pause {
  assert(audioQueue != NULL);
  if (state_ == AS_PLAYING) {
    err = AudioQueuePause(audioQueue);
    CHECK_ERR(err, AS_AUDIO_QUEUE_PAUSE_FAILED);
    [self setState:AS_PAUSED];
  }
}

//
// play
//
// Play the stream if it's not playing
//
- (void) play {
  assert(audioQueue != NULL);
  if (state_ == AS_PAUSED) {
    err = AudioQueueStart(audioQueue, NULL);
    CHECK_ERR(err, AS_AUDIO_QUEUE_START_FAILED);
    [self setState:AS_PLAYING];
  }
}

//
// stop
//
// This method can be called to stop downloading/playback before it completes.
// It is automatically called when an error occurs.
//
// If playback has not started before this method is called, it will toggle the
// "isPlaying" property so that it is guaranteed to transition to true and
// back to false
//
- (void)stop {
  if (![self isDone]) {
    [self setState:AS_STOPPED];
  }

  [self closeReadStream];

  //
  // Close the audio file strea,
  //
  if (audioFileStream) {
    err = AudioFileStreamClose(audioFileStream);
    assert(!err);
    audioFileStream = nil;
  }

  //
  // Dispose of the Audio Queue
  //
  if (audioQueue) {
    AudioQueueStop(audioQueue, true);
    err = AudioQueueDispose(audioQueue, true);
    assert(!err);
    audioQueue = nil;
  }

  httpHeaders      = nil;
  bytesFilled      = 0;
  packetsFilled    = 0;
  seekByteOffset   = 0;
  packetBufferSize = 0;
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
  assert(!waitingOnBuffer);
  events++;

  switch (eventType) {
    case kCFStreamEventErrorOccurred:
      LOG(@"error");
      networkError = (__bridge_transfer NSError*) CFReadStreamCopyError(aStream);
      [self failWithErrorCode:AS_NETWORK_CONNECTION_FAILED];
      return;

    case kCFStreamEventEndEncountered:
      LOG(@"end");

      /* Flush out extra data if necessary */
      if (bytesFilled) {
        /* Disregard return value because we're at the end of the stream anyway
           so there's no bother in pausing it */
        if ([self enqueueBuffer] < 0) return;
      }

      /* If we never received any packets, then we fail */
      if (state_ == AS_WAITING_FOR_DATA) {
        [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];

      /* Flush an asynchronously stop the audio queue now that it won't be
         receiving any more data */
      } else {
        if (audioQueue) {
          err = AudioQueueFlush(audioQueue);
          CHECK_ERR(err, AS_AUDIO_QUEUE_FLUSH_FAILED);
          err = AudioQueueStop(audioQueue, false);
          CHECK_ERR(err, AS_AUDIO_QUEUE_STOP_FAILED);
        }
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
    //
    // Attempt to guess the file type from the URL. Reading the MIME type
    // from the httpHeaders might be a better approach since lots of
    // URL's don't have the right extension.
    //
    // If you have a fixed file-type, you may want to hardcode this.
    //
    AudioFileTypeID fileTypeHint =
      [AudioStreamer hintForFileExtension:[[url path] pathExtension]];

    // create an audio file stream parser
    err = AudioFileStreamOpen((__bridge void*) self, MyPropertyListenerProc,
                              MyPacketsProc, fileTypeHint, &audioFileStream);
    CHECK_ERR(err, AS_FILE_STREAM_OPEN_FAILED);
  }

  UInt8 bytes[kAQDefaultBufSize];
  CFIndex length;
  while (state_ != AS_STOPPED && CFReadStreamHasBytesAvailable(stream)) {
    length = CFReadStreamRead(stream, bytes, kAQDefaultBufSize);

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
  AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
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
    //
    // Fill all the buffers before starting. This ensures that the
    // AudioFileStream stays a small amount ahead of the AudioQueue to
    // avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
    //
    if (buffersUsed == kNumAQBufs - 1) {
      err = AudioQueueStart(audioQueue, NULL);
      if (err) {
        [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
        return -1;
      }
      [self setState:AS_WAITING_FOR_QUEUE_TO_START];
    }
  }

  /* move on to the next buffer and wait for it to be in use */
  if (++fillBufferIndex >= kNumAQBufs) fillBufferIndex = 0;
  bytesFilled   = 0;    // reset bytes filled
  packetsFilled = 0;    // reset packets filled

  @synchronized(self) {
    if (inuse[fillBufferIndex]) {
      LOG(@"waiting for buffer %d", fillBufferIndex);
      CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(),
                                        kCFRunLoopCommonModes);
      unscheduled = YES;
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
      packetBufferSize = kAQDefaultBufSize;
    }
  }

  // allocate audio queue buffers
  for (unsigned int i = 0; i < kNumAQBufs; ++i) {
    err = AudioQueueAllocateBuffer(audioQueue, packetBufferSize,
                                   &audioQueueBuffer[i]);
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
      /* TODO: why? */
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

    /* TODO: if AAC or SBR needs to be supported, fix this */
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
  int i;
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
  SInt64 packetSize = desc->mDataByteSize;

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
  AudioQueueBufferRef buf = audioQueueBuffer[fillBufferIndex];
  memcpy(buf->mAudioData + bytesFilled, data, packetSize);

  // fill out packet description to pass to enqueue() later on
  packetDescs[packetsFilled] = *desc;
  // Make sure the offset is relative to the start of the audio buffer
  packetDescs[packetsFilled].mStartOffset = bytesFilled;
  // keep track of bytes filled and packets filled
  bytesFilled += packetSize;
  packetsFilled++;

  /* Make sure that our packets per buffer don't get backed up too much */
  if (packetsFilled >= kAQMaxPacketDescs) return -1;
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
    CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),
                                    kCFRunLoopCommonModes);
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
  int idx;
  for (idx = 0; idx < kNumAQBufs; idx++) {
    if (audioQueueBuffer[idx] == inBuffer) break;
  }
  assert(idx >= 0 && idx < kNumAQBufs);
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

@end
