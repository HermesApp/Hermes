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

#if defined(DEBUG) && 0
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

@synthesize errorCode;
@synthesize networkError;
@synthesize httpHeaders;
@synthesize url;
@synthesize fileType;
@synthesize bufferCnt;
@synthesize bufferSize;
@synthesize bufferInfinite;
@synthesize timeoutInterval;

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

+ (AudioStreamer*) streamWithURL:(NSURL*)url{
  assert(url != nil);
  AudioStreamer *stream = [[AudioStreamer alloc] init];
  stream->url = url;
  stream->bufferCnt  = kDefaultNumAQBufs;
  stream->bufferSize = kDefaultAQDefaultBufSize;
  stream->timeoutInterval = 10;
  return stream;
}

- (void)dealloc {
  [self stop];
  assert(queued_head == NULL);
  assert(queued_tail == NULL);
  assert(timeout == nil);
  assert(buffers == NULL);
  assert(inuse == NULL);
}

- (void) setHTTPProxy:(NSString*)host port:(int)port {
  proxyHost = host;
  proxyPort = port;
  proxyType = PROXY_HTTP;
}

- (void) setSOCKSProxy:(NSString*)host port:(int)port {
  proxyHost = host;
  proxyPort = port;
  proxyType = PROXY_SOCKS;
}

- (BOOL)setVolume: (double) volume {
  if (audioQueue != NULL) {
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, volume);
    return YES;
  }
  return NO;
}

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

- (BOOL)isPlaying {
  return state_ == AS_PLAYING;
}

- (BOOL)isPaused {
  return state_ == AS_PAUSED;
}

- (BOOL)isWaiting {
  return state_ == AS_WAITING_FOR_DATA ||
         state_ == AS_WAITING_FOR_QUEUE_TO_START;
}

- (BOOL)isDone {
  return state_ == AS_DONE || state_ == AS_STOPPED;
}

- (BOOL) start {
  if (stream != NULL) return NO;
  assert(audioQueue == NULL);
  assert(state_ == AS_INITIALIZED);
  [self openReadStream];
  timeout = [NSTimer scheduledTimerWithTimeInterval:timeoutInterval
                                             target:self
                                           selector:@selector(checkTimeout)
                                           userInfo:nil
                                            repeats:YES];
  return YES;
}

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

- (BOOL) duration:(double*)ret {
  double calculatedBitRate;
  if (![self calculatedBitRate:&calculatedBitRate]) return NO;
  if (calculatedBitRate == 0 || fileLength == 0) {
    return NO;
  }

  *ret = (fileLength - dataOffset) / (calculatedBitRate * 0.125);
  return YES;
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
  if ([fileExtension isEqual:@"mp3"]) {
    return kAudioFileMP3Type;
  } else if ([fileExtension isEqual:@"wav"]) {
    return kAudioFileWAVEType;
  } else if ([fileExtension isEqual:@"aifc"]) {
    return kAudioFileAIFCType;
  } else if ([fileExtension isEqual:@"aiff"]) {
    return kAudioFileAIFFType;
  } else if ([fileExtension isEqual:@"m4a"]) {
    return kAudioFileM4AType;
  } else if ([fileExtension isEqual:@"mp4"]) {
    return kAudioFileMPEG4Type;
  } else if ([fileExtension isEqual:@"caf"]) {
    return kAudioFileCAFType;
  } else if ([fileExtension isEqual:@"aac"]) {
    return kAudioFileAAC_ADTSType;
  }
  return 0;
}

/**
 * @brief Guess the file type based on the listed MIME type in the http response
 *
 * Code from:
 * https://github.com/DigitalDJ/AudioStreamer/blob/master/Classes/AudioStreamer.m
 */
+ (AudioFileTypeID) hintForMIMEType:(NSString*)mimeType {
  if ([mimeType isEqual:@"audio/mpeg"]) {
    return kAudioFileMP3Type;
  } else if ([mimeType isEqual:@"audio/x-wav"]) {
    return kAudioFileWAVEType;
  } else if ([mimeType isEqual:@"audio/x-aiff"]) {
    return kAudioFileAIFFType;
  } else if ([mimeType isEqual:@"audio/x-m4a"]) {
    return kAudioFileM4AType;
  } else if ([mimeType isEqual:@"audio/mp4"]) {
    return kAudioFileMPEG4Type;
  } else if ([mimeType isEqual:@"audio/x-caf"]) {
    return kAudioFileCAFType;
  } else if ([mimeType isEqual:@"audio/aac"] ||
             [mimeType isEqual:@"audio/aacp"]) {
    return kAudioFileAAC_ADTSType;
  }
  return 0;
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
   NSString *str = [NSString stringWithFormat:@"bytes=%lld-%lld",
                                              seekByteOffset, fileLength - 1];
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
          @(proxyPort), kCFStreamPropertyHTTPProxyPort,
          nil];
      CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPProxy,
                              proxySettings);
      break;
    }
    case PROXY_SOCKS: {
      CFDictionaryRef proxySettings = (__bridge CFDictionaryRef)
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
          proxyHost, kCFStreamPropertySOCKSProxyHost,
          @(proxyPort), kCFStreamPropertySOCKSProxyPort,
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
    NSDictionary *sslSettings = @{
      (id)kCFStreamSSLLevel: (NSString*)kCFStreamSocketSecurityLevelNegotiatedSSL,
      (id)kCFStreamSSLAllowsExpiredCertificates:  @NO,
      (id)kCFStreamSSLAllowsExpiredRoots:         @NO,
      (id)kCFStreamSSLAllowsAnyRoot:              @NO,
      (id)kCFStreamSSLValidatesCertificateChain:  @YES,
      (id)kCFStreamSSLPeerName:                   [NSNull null]
    };

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
      fileLength = [httpHeaders[@"Content-Length"] integerValue];
    }
  }

  /* If we haven't yet opened up a file stream, then do so now */
  if (!audioFileStream) {
    /* If a file type wasn't specified, we have to guess */
    if (fileType == 0) {
      fileType = [AudioStreamer hintForMIMEType: httpHeaders[@"Content-Type"]];
      if (fileType == 0) {
        fileType = [AudioStreamer hintForFileExtension:
                      [[url path] pathExtension]];
        if (fileType == 0) {
          fileType = kAudioFileMP3Type;
        }
      }
    }

    // create an audio file stream parser
    err = AudioFileStreamOpen((__bridge void*) self, MyPropertyListenerProc,
                              MyPacketsProc, fileType, &audioFileStream);
    CHECK_ERR(err, AS_FILE_STREAM_OPEN_FAILED);
  }

  UInt8 bytes[2048];
  CFIndex length;
  int i;
  for (i = 0;
       i < 3 && state_ != AS_STOPPED && CFReadStreamHasBytesAvailable(stream);
       i++) {
    length = CFReadStreamRead(stream, bytes, sizeof(bytes));

    if (length < 0) {
      [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
      return;
    } else if (length == 0) {
      return;
    }

    if (discontinuous) {
      err = AudioFileStreamParseBytes(audioFileStream, (UInt32) length, bytes,
                                      kAudioFileStreamParseFlag_Discontinuity);
    } else {
      err = AudioFileStreamParseBytes(audioFileStream, (UInt32) length,
                                      bytes, 0);
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
  }

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
                            (__bridge void*) self, CFRunLoopGetCurrent(), NULL,
                            0, &audioQueue);
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
  /* Sanity check to make sure we're on the right thread */
  assert([NSThread currentThread] == [NSThread mainThread]);

  /* Figure out which buffer just became free, and it had better damn well be
     one of our own buffers */
  UInt32 idx;
  for (idx = 0; idx < bufferCnt; idx++) {
    if (buffers[idx] == inBuffer) break;
  }
  assert(idx >= 0 && idx < bufferCnt);
  assert(inuse[idx]);

  LOG(@"buffer %d finished", idx);

  /* Signal the buffer is no longer in use */
  inuse[idx] = false;
  buffersUsed--;

  /* If there is absolutely no more data which will ever come into the stream,
   * then we're done with the audio */
  if (buffersUsed == 0 && queued_head == NULL && stream != nil &&
      CFReadStreamGetStatus(stream) == kCFStreamStatusAtEnd) {
    assert(!waitingOnBuffer);
    [self setState:AS_DONE];

  /* Otherwise we just opened up a buffer so try to fill it with some cached
   * data if there is any available */
  } else if (waitingOnBuffer) {
    waitingOnBuffer = false;
    [self enqueueCachedData];
  }
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
  /* Sanity check to make sure we're on the expected thread */
  assert([NSThread currentThread] == [NSThread mainThread]);
  /* We only asked for one property, so the audio queue had better damn well
     only tell us about this property */
  assert(inID == kAudioQueueProperty_IsRunning);

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
