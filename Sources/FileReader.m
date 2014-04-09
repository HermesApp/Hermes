//
//  FileReader.m
//  Hermes
//
//  Created by Alex Crichton on 6/29/12.
//

#import "FileReader.h"

@implementation FileReader

+ (FileReader*) readerForFile:(NSString*)path
            completionHandler:(FileReadCallback) cb {
  FileReader *reader = [[FileReader alloc] init];
  reader->stream = [NSInputStream inputStreamWithFileAtPath:path];
  reader->cb = [cb copy];
  reader->bytes = [NSMutableData data];
  return reader;
}

- (void)stream:(NSStream *)s handleEvent:(NSStreamEvent)eventCode {
  NSError *error = nil;
  uint8_t buffer[1024];
  switch (eventCode) {
    case NSStreamEventHasBytesAvailable: {
      NSUInteger len = [stream read:buffer maxLength:1024];
      if (len)
        [bytes appendBytes:buffer length:len];
      return;
    }
    case NSStreamEventEndEncountered:
      break;
    case NSStreamEventErrorOccurred:
      bytes = nil;
      error = [stream streamError];
      break;
    default:
      return;
  }
  NSLogd(@"notifying");
  cb(bytes, error);
  [s close];
  [s removeFromRunLoop:[NSRunLoop currentRunLoop]
               forMode:NSDefaultRunLoopMode];
}

- (void) start {
  [stream setDelegate:self];
  [stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                    forMode:NSDefaultRunLoopMode];
  [stream open];
}

@end
