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

- (void)internalSeekToTime:(double)newSeekTime;
- (void)enqueueBuffer;
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
@synthesize bitRate;
@synthesize httpHeaders;

//
// initWithURL
//
// Init method for the object.
//
- (id)initWithURL:(NSURL *)aURL {
  url = aURL;
  requestingVolume = NO;
  return self;
}

- (void)setVolume: (double) volume {
  requestedVolume = volume;
  requestingVolume = YES;
  NSLog(@"requesting");
}

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc {
  [self stop];
}

//
// isFinishing
//
// returns YES if the audio has reached a stopping condition.
//
- (BOOL)isFinishing {
  @synchronized (self) {
    return (errorCode != AS_NO_ERROR && state_ != AS_INITIALIZED) ||
           ((state_ == AS_STOPPING || state_ == AS_STOPPED) &&
            stopReason != AS_STOPPING_TEMPORARILY);
  }
}

//
// runLoopShouldExit
//
// returns YES if the run loop should exit.
//
- (BOOL)runLoopShouldExit {
  @synchronized(self) {
    return errorCode != AS_NO_ERROR ||
           (state_ == AS_STOPPED && stopReason != AS_STOPPING_TEMPORARILY);
  }
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
  @synchronized(self) {
    if (errorCode != AS_NO_ERROR) {
      // Only set the error once.
      return;
    }

    errorCode = anErrorCode;

    if (state_ == AS_PLAYING || state_ == AS_PAUSED || state_ == AS_BUFFERING) {
      [self setState:AS_STOPPING];
      stopReason = AS_STOPPING_ERROR;
      AudioQueueStop(audioQueue, true);
    }
  }
}

//
// mainThreadStateNotification
//
// Method invoked on main thread to send notifications to the main thread's
// notification center.
//
- (void)mainThreadStateNotification {
  [[NSNotificationCenter defaultCenter]
        postNotificationName:ASStatusChangedNotification
                      object:self];
}

//
// setState:
//
// Sets the state and sends a notification that the state has changed.
//
// This method
//
// Parameters:
//    anErrorCode - the error condition
//
- (void)setState:(AudioStreamerState)aStatus {
  @synchronized(self) {
    if (state_ == aStatus) return;
    state_ = aStatus;

    if ([[NSThread currentThread] isEqual:[NSThread mainThread]]) {
      [self mainThreadStateNotification];
    } else {
      [self performSelectorOnMainThread:@selector(mainThreadStateNotification)
                             withObject:nil
                          waitUntilDone:NO];
    }
  }
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
  @synchronized(self) {
    return [self isFinishing] ||
        state_ == AS_STARTING_FILE_THREAD||
        state_ == AS_WAITING_FOR_DATA ||
        state_ == AS_WAITING_FOR_QUEUE_TO_START ||
        state_ == AS_BUFFERING;
  }
}

//
// isIdle
//
// returns YES if the AudioStream is in the AS_INITIALIZED state (i.e.
// isn't doing anything).
//
- (BOOL)isIdle {
  return state_ == AS_INITIALIZED;
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

//
// openReadStream
//
// Open the audioFileStream to parse data and the fileHandle as the data
// source.
//
- (BOOL)openReadStream {
  NSAssert([[NSThread currentThread] isEqual:internalThread],
           @"File stream download must be started on the internalThread");
  NSAssert(stream == NULL, @"Download stream already initialized");

  //
  // Create the HTTP GET request
  //
  CFHTTPMessageRef message =
      CFHTTPMessageCreateRequest(NULL,
                                 CFSTR("GET"),
                                 (__bridge CFURLRef) url,
                                 kCFHTTPVersion1_1);

  //
  // If we are creating this request to seek to a location, set the
  // requested byte range in the headers.
  //
  if (fileLength > 0 && seekByteOffset > 0) {
   NSString *str = [NSString stringWithFormat:@"bytes=%ld-%ld",
                                              seekByteOffset, fileLength];
    CFHTTPMessageSetHeaderFieldValue(message,
                                     CFSTR("Range"),
                                     (__bridge CFStringRef) str);
    discontinuous = YES;
  }

  //
  // Create the read stream that will receive data from the HTTP request
  //
  stream = CFReadStreamCreateForHTTPRequest(NULL, message);
  CFRelease(message);

  //
  // Enable stream redirection
  //
  if (CFReadStreamSetProperty(stream,
                              kCFStreamPropertyHTTPShouldAutoredirect,
                              kCFBooleanTrue) == false) {
    [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
    return NO;
  }

  //
  // Handle proxies
  //
  [URLConnection setHermesProxy:stream];

  //
  // Handle SSL connections
  //
  if ([[url absoluteString] rangeOfString:@"https"].location == 0) {
    NSDictionary *sslSettings =
    [NSDictionary dictionaryWithObjectsAndKeys:
     (NSString*)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
     [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
     [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
     [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
     [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
     [NSNull null], kCFStreamSSLPeerName,
     nil];

    CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings,
                            (__bridge CFDictionaryRef) sslSettings);
  }

  //
  // We're now ready to receive data
  //
  [self setState:AS_WAITING_FOR_DATA];

  //
  // Open the stream
  //
  if (!CFReadStreamOpen(stream)) {
    CFRelease(stream);
    [self failWithErrorCode:AS_FILE_STREAM_OPEN_FAILED];
    return NO;
  }

  //
  // Set our callback function to receive the data
  //
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
// startInternal
//
// This is the start method for the AudioStream thread. This thread is created
// because it will be blocked when there are no audio buffers idle (and ready
// to receive audio data).
//
// Activity in this thread:
//  - Creation and cleanup of all AudioFileStream and AudioQueue objects
//  - Receives data from the CFReadStream
//  - AudioFileStream processing
//  - Copying of data from AudioFileStream into audio buffers
//  - Stopping of the thread because of end-of-file
//  - Stopping due to error or failure
//
// Activity *not* in this thread:
//  - AudioQueue playback and notifications (happens in AudioQueue thread)
//  - Actual download of NSURLConnection data (NSURLConnection's thread)
//  - Creation of the AudioStreamer (other, likely "main" thread)
//  - Invocation of -start method (other, likely "main" thread)
//  - User/manual invocation of -stop (other, likely "main" thread)
//
// This method contains bits of the "main" function from Apple's example in
// AudioFileStreamExample.
//
- (void)startInternal {
  @autoreleasepool {

  assert(state_ == AS_STARTING_FILE_THREAD);

  // initialize a mutex and condition so that we can block on buffers in use.
  cond = [[NSCondition alloc] init];

  if (![self openReadStream]) {
    goto cleanup;
  }

  //
  // Process the run loop until playback is finished or failed.
  //
  BOOL isRunning = YES;
  do {
    isRunning = [[NSRunLoop currentRunLoop]
                 runMode:NSDefaultRunLoopMode
                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];

    NSLog(@"run loop iteration");
    @synchronized(self) {
      if (seekWasRequested) {
        seekWasRequested = NO;
        [self internalSeekToTime:requestedSeekTime];
      }
      if (requestingVolume && audioQueue != NULL) {
        requestingVolume = NO;
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume,
                               requestedVolume);
      }
    }

    //
    // If there are no queued buffers, we need to check here since the
    // handleBufferCompleteForQueue:buffer: should not change the state
    // (may not enter the synchronized section).
    //
    if (buffersUsed == 0 && state_ == AS_PLAYING) {
      err = AudioQueuePause(audioQueue);
      CHECK_ERR(err, AS_AUDIO_QUEUE_PAUSE_FAILED);
      [self setState:AS_BUFFERING];
    }
  } while (isRunning && ![self runLoopShouldExit]);

cleanup:

  @synchronized(self)
  {
    //
    // Cleanup the read stream if it is still open
    //
    if (stream) {
      CFReadStreamClose(stream);
      CFRelease(stream);
      stream = nil;
    }

    //
    // Close the audio file strea,
    //
    if (audioFileStream) {
      err = AudioFileStreamClose(audioFileStream);
      audioFileStream = nil;
      if (err)
      {
        [self failWithErrorCode:AS_FILE_STREAM_CLOSE_FAILED];
      }
    }

    //
    // Dispose of the Audio Queue
    //
    if (audioQueue) {
      err = AudioQueueDispose(audioQueue, true);
      audioQueue = nil;
      if (err) {
        [self failWithErrorCode:AS_AUDIO_QUEUE_DISPOSE_FAILED];
      }
    }

    httpHeaders = nil;

    bytesFilled = 0;
    packetsFilled = 0;
    seekByteOffset = 0;
    packetBufferSize = 0;
    [self setState:AS_INITIALIZED];

    internalThread = nil;
  }

  } /* @autoreleasepool */
}

//
// start
//
// Calls startInternal in a new thread.
//
- (void) start {
  assert(audioQueue == NULL);
  assert(state_ == AS_INITIALIZED);
  assert(internalThread == nil);
  NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
           @"Playback can only be started from the main thread.");

  @synchronized (self) {
    notificationCenter = [NSNotificationCenter defaultCenter];
    [self setState:AS_STARTING_FILE_THREAD];
    internalThread = [[NSThread alloc] initWithTarget:self
                                             selector:@selector(startInternal)
                                               object:nil];
    [internalThread start];
  }
}

// internalSeekToTime:
//
// Called from our internal runloop to reopen the stream at a seeked location
//
- (void)internalSeekToTime:(double)newSeekTime
{
  if ([self calculatedBitRate] == 0.0 || fileLength <= 0) {
    return;
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
  if (packetDuration > 0 && calculatedBitRate > 0) {
    UInt32 ioFlags = 0;
    SInt64 packetAlignedByteOffset;
    SInt64 seekPacket = floor(newSeekTime / packetDuration);
    err = AudioFileStreamSeek(audioFileStream, seekPacket, &packetAlignedByteOffset, &ioFlags);
    if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
      seekTime -= ((seekByteOffset - dataOffset) - packetAlignedByteOffset) * 8.0 / calculatedBitRate;
      seekByteOffset = packetAlignedByteOffset + dataOffset;
    }
  }

  //
  // Close the current read straem
  //
  if (stream) {
    CFReadStreamClose(stream);
    CFRelease(stream);
    stream = nil;
  }

  //
  // Stop the audio queue
  //
  [self setState:AS_STOPPING];
  stopReason = AS_STOPPING_TEMPORARILY;
  err = AudioQueueStop(audioQueue, true);
  CHECK_ERR(err, AS_AUDIO_QUEUE_STOP_FAILED);

  //
  // Re-open the file stream. It will request a byte-range starting at
  // seekByteOffset.
  //
  [self openReadStream];
}

//
// seekToTime:
//
// Attempts to seek to the new time. Will be ignored if the bitrate or fileLength
// are unknown.
//
// Parameters:
//    newTime - the time to seek to
//
- (void)seekToTime:(double)newSeekTime {
  @synchronized(self) {
    seekWasRequested = YES;
    requestedSeekTime = newSeekTime;
  }
}

//
// progress
//
// returns the current playback progress. Will return zero if sampleRate has
// not yet been detected.
//
- (double)progress {
  @synchronized(self) {
    if (sampleRate > 0 && ![self isFinishing]) {
      if (state_ != AS_PLAYING && state_ != AS_PAUSED &&
          state_ != AS_BUFFERING) {
        return lastProgress;
      }

      AudioTimeStamp queueTime;
      Boolean discontinuity;
      err = AudioQueueGetCurrentTime(audioQueue, NULL, &queueTime, &discontinuity);

      const OSStatus AudioQueueStopped = 0x73746F70; // 0x73746F70 is 'stop'
      if (err == AudioQueueStopped) {
        return lastProgress;
      } else if (err) {
        [self failWithErrorCode:AS_GET_AUDIO_TIME_FAILED];
      }

      double progress = seekTime + queueTime.mSampleTime / sampleRate;
      if (progress < 0.0)
      {
        progress = 0.0;
      }

      lastProgress = progress;
      return progress;
    }
  }

  return lastProgress;
}

//
// calculatedBitRate
//
// returns the bit rate, if known. Uses packet duration times running bits per
//   packet if available, otherwise it returns the nominal bitrate. Will return
//   zero if no useful option available.
//
- (double)calculatedBitRate
{
  if (packetDuration && processedPacketsCount > BitRateEstimationMinPackets)
  {
    double averagePacketByteSize = processedPacketsSizeTotal / processedPacketsCount;
    return 8.0 * averagePacketByteSize / packetDuration;
  }

  if (bitRate)
  {
    return (double)bitRate;
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
  @synchronized(self) {
    if (state_ == AS_PLAYING) {
      err = AudioQueuePause(audioQueue);
      CHECK_ERR(err, AS_AUDIO_QUEUE_PAUSE_FAILED);
      [self setState:AS_PAUSED];
    }
  }
}

//
// play
//
// Play the stream if it's not playing
//
- (void) play {
  assert(audioQueue != NULL);
  @synchronized(self) {
    if (state_ == AS_PAUSED) {
      err = AudioQueueStart(audioQueue, NULL);
      CHECK_ERR(err, AS_AUDIO_QUEUE_START_FAILED);
      [self setState:AS_PLAYING];
    }
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
  @synchronized(self) {
    if (audioQueue &&
        (state_ == AS_PLAYING || state_ == AS_PAUSED ||
         state_ == AS_BUFFERING || state_ == AS_WAITING_FOR_QUEUE_TO_START)) {
      [self setState:AS_STOPPING];
      stopReason = AS_STOPPING_USER_ACTION;
      err = AudioQueueStop(audioQueue, true);
      CHECK_ERR(err, AS_AUDIO_QUEUE_STOP_FAILED);
    } else if (state_ != AS_INITIALIZED) {
      [self setState:AS_STOPPED];
      stopReason = AS_STOPPING_USER_ACTION;
    }
    seekWasRequested = NO;
  }

  while (state_ != AS_INITIALIZED) {
    [NSThread sleepForTimeInterval:0.1];
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

  switch (eventType) {
    case kCFStreamEventErrorOccurred:
      networkError = (__bridge_transfer NSError*) CFReadStreamCopyError(aStream);
      [self failWithErrorCode:AS_NETWORK_CONNECTION_FAILED];
      return;

    case kCFStreamEventEndEncountered:
      if ([self isFinishing]) return;

      //
      // If there is a partially filled buffer, pass it to the AudioQueue for
      // processing
      //
      if (bytesFilled) {
        if (state_ == AS_WAITING_FOR_DATA) {
          //
          // Force audio data smaller than one whole buffer to play.
          //
          [self setState:AS_FLUSHING_EOF];
        }
        [self enqueueBuffer];
      }

      @synchronized(self) {
        if (state_ == AS_WAITING_FOR_DATA) {
          [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];

        //
        // We left the synchronized section to enqueue the buffer so we
        // must check that we are !finished again before touching the
        // audioQueue
        //
        } else if (![self isFinishing]) {
          if (audioQueue) {
            //
            // Set the progress at the end of the stream
            //
            err = AudioQueueFlush(audioQueue);
            CHECK_ERR(err, AS_AUDIO_QUEUE_FLUSH_FAILED);

            [self setState:AS_STOPPING];
            stopReason = AS_STOPPING_EOF;
            err = AudioQueueStop(audioQueue, false);
            CHECK_ERR(err, AS_AUDIO_QUEUE_STOP_FAILED);
          } else {
            [self setState:AS_STOPPED];
            stopReason = AS_STOPPING_EOF;
          }
        }
      }
      return;

    default:
      return;

    case kCFStreamEventHasBytesAvailable:
      break;
  }

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
  while (1) {
    if ([self isFinishing] || !CFReadStreamHasBytesAvailable(stream)) {
      return;
    }

    //
    // Read the bytes from the stream
    //
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
- (void) enqueueBuffer {
  assert(stream != NULL);
  if ([self isFinishing]) { return; }

  assert(!inuse[fillBufferIndex]);
  inuse[fillBufferIndex] = true;    // set in use flag
  buffersUsed++;

  // enqueue buffer
  AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
  fillBuf->mAudioDataByteSize = bytesFilled;

  assert(packetsFilled > 0);
  err = AudioQueueEnqueueBuffer(audioQueue, fillBuf, packetsFilled,
                                packetDescs);
  CHECK_ERR(err, AS_AUDIO_QUEUE_ENQUEUE_FAILED);

  if (state_ == AS_BUFFERING ||
      state_ == AS_WAITING_FOR_DATA ||
      state_ == AS_FLUSHING_EOF ||
      (state_ == AS_STOPPED && stopReason == AS_STOPPING_TEMPORARILY)) {
    //
    // Fill all the buffers before starting. This ensures that the
    // AudioFileStream stays a small amount ahead of the AudioQueue to
    // avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
    //
    /* TODO: this is fucked up, start earlier? Reorganize code? what's with the
             state transitions down here? */
    if (state_ == AS_FLUSHING_EOF || buffersUsed == kNumAQBufs - 1) {
      if (state_ == AS_BUFFERING) {
        err = AudioQueueStart(audioQueue, NULL);
        CHECK_ERR(err, AS_AUDIO_QUEUE_START_FAILED);
        [self setState:AS_PLAYING];
      } else {
        [self setState:AS_WAITING_FOR_QUEUE_TO_START];
        err = AudioQueueStart(audioQueue, NULL);
        CHECK_ERR(err, AS_AUDIO_QUEUE_START_FAILED);
      }
    }
  }

  /* move on to the next buffer and wait for it to be in use */
  if (++fillBufferIndex >= kNumAQBufs) fillBufferIndex = 0;
  bytesFilled   = 0;    // reset bytes filled
  packetsFilled = 0;    // reset packets filled

  // wait until next buffer is not in use
  [cond lock];
  while (inuse[fillBufferIndex]) {
    [cond wait];
  }
  [cond unlock];
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
  sampleRate = asbd.mSampleRate;
  packetDuration = asbd.mFramesPerPacket / sampleRate;

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
  if ([self isFinishing]) {
    return;
  }

  switch (inPropertyID) {
    case kAudioFileStreamProperty_ReadyToProducePackets:
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
      break;
    }

    case kAudioFileStreamProperty_AudioDataByteCount: {
      UInt32 byteCountSize = sizeof(UInt64);
      err = AudioFileStreamGetProperty(inAudioFileStream,
              kAudioFileStreamProperty_AudioDataByteCount,
              &byteCountSize, &audioDataByteCount);
      CHECK_ERR(err, AS_FILE_STREAM_GET_PROPERTY_FAILED);
      fileLength = dataOffset + audioDataByteCount;
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

  if ([self isFinishing]) {
    return;
  }

  if (bitRate == 0) {
    //
    // m4a and a few other formats refuse to parse the bitrate so
    // we need to set an "unparseable" condition here. If you know
    // the bitrate (parsed it another way) you can set it on the
    // class if needed.
    //
    bitRate = ~0;
  }

  // we have successfully read the first packests from the audio stream, so
  // clear the "discontinuous" flag
  if (discontinuous) {
    discontinuous = false;
  }

  if (!audioQueue) {
    [self createQueue];
  }
  assert(inPacketDescriptions != NULL);

  /* Place each packet into a buffer and then send each buffer into the audio
     queue */
  for (int i = 0; i < inNumberPackets; i++) {
    SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
    SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;

    /* global statistics */
    processedPacketsSizeTotal += packetSize;
    processedPacketsCount++;

    // If the audio was terminated before this point, then
    // exit.
    if ([self isFinishing]) { return; }

    /* This shouldn't happen because most of the time we read the packet buffer
       size from the file stream, but if we restored to guessing it we could
       come up too small here */
    CHECK_ERR(packetSize > packetBufferSize, AS_AUDIO_BUFFER_TOO_SMALL);

    // if the space remaining in the buffer is not enough for this packet, then
    // enqueue the buffer and wait for another to become available.
    if (packetBufferSize - bytesFilled < packetSize) {
      [self enqueueBuffer];
      /* if we terminated while waiting, then bail out */
      if ([self isFinishing]) { return; }
      assert(bytesFilled == 0);
      assert(packetBufferSize >= packetSize);
    }

    // copy data to the audio queue buffer
    AudioQueueBufferRef buf = audioQueueBuffer[fillBufferIndex];
    memcpy(buf->mAudioData + bytesFilled,
           inInputData + packetOffset,
           packetSize);

    // fill out packet description to pass to enqueue() later on
    packetDescs[packetsFilled] = inPacketDescriptions[i];
    // Make sure the offset is relative to the start of the audio buffer
    packetDescs[packetsFilled].mStartOffset = bytesFilled;
    // keep track of bytes filled and packets filled
    bytesFilled += packetSize;
    packetsFilled++;

    // if that was the last free packet description, then enqueue the buffer.
    if (packetsFilled >= kAQMaxPacketDescs) {
      [self enqueueBuffer];
      assert(packetsFilled == 0);
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
  assert([NSThread currentThread] != internalThread);
  assert([NSThread currentThread] != [NSThread mainThread]);

  /* Figure out which buffer just became free, and it had better damn well be
     one of our own buffers */
  int idx;
  for (idx = 0; idx < kNumAQBufs; idx++) {
    if (audioQueueBuffer[idx] == inBuffer) break;
  }
  assert(idx >= 0 && idx < kNumAQBufs);
  assert(inuse[idx]);

  // signal waiting thread that the buffer is free.
  [cond lock];
  inuse[idx] = false;
  buffersUsed--;
  [cond signal];
  [cond unlock];
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
  assert([NSThread currentThread] != internalThread);
  assert([NSThread currentThread] != [NSThread mainThread]);
  /* We only asked for one property, so the audio queue had better damn well
     only tell us about this property */
  assert(inID == kAudioQueueProperty_IsRunning);

  @autoreleasepool {

  @synchronized(self) {
    if (state_ == AS_STOPPING) {
      [self setState:AS_STOPPED];
    } else if (state_ == AS_WAITING_FOR_QUEUE_TO_START) {
      //
      // Note about this bug avoidance quirk:
      //
      // On cleanup of the AudioQueue thread, on rare occasions, there would
      // be a crash in CFSetContainsValue as a CFRunLoopObserver was getting
      // removed from the CFRunLoop.
      //
      // After lots of testing, it appeared that the audio thread was
      // attempting to remove CFRunLoop observers from the CFRunLoop after the
      // thread had already deallocated the run loop.
      //
      // By creating an NSRunLoop for the AudioQueue thread, it changes the
      // thread destruction order and seems to avoid this crash bug -- or
      // at least I haven't had it since (nasty hard to reproduce error!)
      //
      [NSRunLoop currentRunLoop];

      [self setState:AS_PLAYING];
    } else {
      NSLog(@"AudioQueue changed state in unexpected way.");
    }
  }

  }
}

@end
