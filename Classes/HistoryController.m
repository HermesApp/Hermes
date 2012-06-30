//
//  HistoryController.m
//  Hermes
//
//  Created by Alex Crichton on 10/9/11.
//

#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "FileReader.h"
#import "Pandora/Song.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "StationsController.h"

#define HISTORY_LIMIT 20

@implementation HistoryController

@synthesize songs, controller;

- (void) loadSavedSongs {
  NSLogd(@"loading saved songs");
  NSString *saved_state = [[NSApp delegate] stateDirectory:@"history.savestate"];
  if (saved_state == nil) { return; }
  reader = [FileReader readerForFile:saved_state
                   completionHandler:^(NSData *data, NSError *err) {
    if (err) return;
    assert(data != nil);
    NSArray *s = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    [controller addObjects:s];
    reader = nil;
  }];
  [reader start];
}

- (void) insertObject:(Song *)s inSongsAtIndex:(NSUInteger)index {
  [songs insertObject:s atIndex:index];
}

- (void) removeObjectFromSongsAtIndex:(NSUInteger)index {
  [songs removeObjectAtIndex:index];
}

- (void) addSong:(Song *)song {
  if (songs == nil) {
    [self loadSavedSongs];
    songs = [NSMutableArray array];
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

- (Song*) selectedItem {
  NSUInteger selection = [controller selectionIndex];
  if (selection == NSNotFound) {
    return nil;
  }
  return [songs objectAtIndex:selection];
}

- (Pandora*) pandora {
  return [[NSApp delegate] pandora];
}

- (void) updateThumbs {
  Song* s = [self selectedItem];
  [like setEnabled:NO];
  [dislike setEnabled:NO];
  if (s == nil) return;

  [like setEnabled:[[s nrating] intValue] != 1];
  [dislike setEnabled:[[s nrating] intValue] != -1];
}

- (IBAction) dislikeSelected:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  [[self pandora] rateSong:s as:NO];
  [like setEnabled:YES];
  [dislike setEnabled:NO];
}

- (IBAction)gotoSong:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSURL *url = [NSURL URLWithString:[s titleUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)gotoArtist:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSURL *url = [NSURL URLWithString:[s artistUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)gotoAlbum:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSURL *url = [NSURL URLWithString:[s albumUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction) likeSelected:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  [[self pandora] rateSong:s as:YES];
  [like setEnabled:NO];
  [dislike setEnabled:YES];
}

- (NSSize) drawerWillResizeContents:(NSDrawer*) drawer toSize:(NSSize) size {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:size.width forKey:HIST_DRAWER_WIDTH];
  return size;
}

- (void) showDrawer {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSSize s;
  s.height = 100;
  s.width = [defaults integerForKey:HIST_DRAWER_WIDTH];
  [drawer open];
  [drawer setContentSize:s];
}

- (void) hideDrawer {
  [drawer close];
}

@end
