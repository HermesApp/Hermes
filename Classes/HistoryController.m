//
//  HistoryController.m
//  Hermes
//
//  Created by Alex Crichton on 10/9/11.
//

#import "HermesAppDelegate.h"
#import "Pandora/Song.h"
#import "HistoryController.h"

#define HISTORY_LIMIT 20

@implementation HistoryController

@synthesize songs, controller;

- (NSMutableArray*) loadSavedSongs {
  NSString *saved_state = [[NSApp delegate] stateDirectory:@"history.savestate"];
  if (saved_state == nil) {
    return [NSMutableArray array];
  }
  NSArray *s = [NSKeyedUnarchiver unarchiveObjectWithFile:saved_state];
  return [NSMutableArray arrayWithArray:s];
}

- (IBAction) showHistory:(id)sender {
  [NSApp beginSheet: history
     modalForWindow: [[NSApp delegate] window]
      modalDelegate: self
     didEndSelector: NULL
        contextInfo: nil];

  [collection setSelectable:false];
  [collection setMaxNumberOfColumns:1];
  [collection setMaxNumberOfRows:HISTORY_LIMIT];

  if (songs == nil) {
    [self setSongs:[self loadSavedSongs]];
  }
}

- (IBAction) closeHistory:(id)sender {
  [NSApp endSheet:history];
  [history orderOut:self];
}

- (void) insertObject:(Song *)s inSongsAtIndex:(NSUInteger)index {
  [songs insertObject:s atIndex:index];
}

- (void) removeObjectFromSongsAtIndex:(NSUInteger)index {
  [songs removeObjectAtIndex:index];
}

- (void) addSong:(Song *)song {
  if (songs == nil) {
    [self setSongs:[self loadSavedSongs]];
  }
  [self insertObject:song inSongsAtIndex:0];

  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName:@"hermes.song"
                  object:@"hermes"
                userInfo:[song toDictionary]];

  while ([songs count] > HISTORY_LIMIT) {
    [self removeObjectFromSongsAtIndex:HISTORY_LIMIT];
  }
}

- (BOOL) saveSongs {
  NSString *path = [[NSApp delegate] stateDirectory:@"history.savestate"];
  if (path == nil) {
    return NO;
  }

  return [NSKeyedArchiver archiveRootObject:songs toFile:path];
}

@end
