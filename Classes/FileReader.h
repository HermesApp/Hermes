//
//  FileReader.h
//  Hermes
//
//  Created by Alex Crichton on 6/29/12.
//

typedef void(^FileReadCallback)(NSData*, NSError*);

@interface FileReader : NSObject <NSStreamDelegate> {
  NSInputStream *stream;
  FileReadCallback cb;
  NSMutableData *bytes;
}

+ (FileReader*) readerForFile:(NSString*)path
            completionHandler:(FileReadCallback) cb;

- (void) start;

@end
