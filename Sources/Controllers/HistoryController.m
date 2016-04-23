//
//  HistoryController.m
//  Hermes
//
//  Created by Alex Crichton on 10/9/11.
//

#import "HermesAppDelegate.h"
#import "HistoryController.h"
#import "FileReader.h"
#import "FMEngine/NSString+FMEngine.h"
#import "Pandora/Song.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "StationsController.h"
#import "URLConnection.h"
#import "Notifications.h"

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
    for (Song *song in s) {
      if ([songs indexOfObject:song] == NSNotFound)
        [controller addObject:song];
    }
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
    postNotificationName:HistoryControllerDidPlaySongDistributedNotification
                  object:@"hermes"
                userInfo:[song toDictionary]
                deliverImmediately: YES];

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
  return songs[selection];
}

- (Pandora*) pandora {
  return [[NSApp delegate] pandora];
}

- (void) setEnabledState:(BOOL)enabled allowRating:(BOOL)ratingEnabled {
  [pandoraSong setEnabled:enabled];
  [pandoraArtist setEnabled:enabled];
  [pandoraAlbum setEnabled:enabled];
  [lyrics setEnabled:enabled];
  [like setEnabled:ratingEnabled];
  [dislike setEnabled:ratingEnabled];
}

- (void) updateUI {
  Song *song = [self selectedItem];
  int rating = 0;
  if (song && [[song station] shared]) {
    [self setEnabledState:YES allowRating:NO];
  }
  else if (song) {
    [self setEnabledState:YES allowRating:YES];
    rating = [[song nrating] intValue];
  }
  else {
    [self setEnabledState:NO allowRating:NO];
  }

  if (rating == -1) {
    [like setState:NSOffState];
    [dislike setState:NSOnState];
  }
  else if (rating == 0) {
    [like setState:NSOffState];
    [dislike setState:NSOffState];
  }
  else if (rating == 1) {
    [like setState:NSOnState];
    [dislike setState:NSOffState];
  }
}

- (IBAction) dislikeSelected:(id)sender {
  Song* song = [self selectedItem];
  if (!song) return;
  [[[NSApp delegate] playback] rate:song as:NO];
}

- (IBAction) likeSelected:(id)sender {
  Song* song = [self selectedItem];
  if (!song) return;
  [[[NSApp delegate] playback] rate:song as:YES];
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

- (NSSize) drawerWillResizeContents:(NSDrawer*) drawer toSize:(NSSize) size {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:size.width forKey:HIST_DRAWER_WIDTH];
  return size;
}

- (void)drawerWillClose:(NSNotification *)notification {
  PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_NONE_HIST);
}

- (void) showDrawer {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSSize s;
  s.height = 100;
  s.width = [defaults integerForKey:HIST_DRAWER_WIDTH];
  [drawer open];
  [drawer setContentSize:s];
  [collection setMaxItemSize:NSMakeSize(227, 40)];
  [collection setMinItemSize:NSMakeSize(40, 40)];
  [self focus];
}

- (void) hideDrawer {
  [drawer close];
}

- (void) focus {
  [[drawer parentWindow] makeFirstResponder:collection];
}

- (IBAction) showLyrics:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSString *surl =
    [NSString
      stringWithFormat:@"http://lyrics.wikia.com/api.php?artist=%@&song=%@&fmt=realjson",
      [[s artist] urlEncoded], [[s title] urlEncoded]];
  NSURL *url = [NSURL URLWithString:surl];
  NSURLRequest *req = [NSURLRequest requestWithURL:url];
  NSLogd(@"Fetch: %@", surl);
  URLConnection *conn = [URLConnection connectionForRequest:req
                                  completionHandler:^(NSData *d, NSError *err) {
    if (err == nil) {

      NSDictionary *object = [NSJSONSerialization JSONObjectWithData:d options:nil error:&err];
      if (err == nil) {
        NSString *url = object[@"url"];
        [spinner setHidden:YES];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
        return;
      }
    }
    NSAlert *alert = [NSAlert alertWithError:err];
    [alert setMessageText:@"Couldn't open lyrics"];
    [alert setInformativeText:[err localizedDescription]];
    [alert beginSheetModalForWindow:[[NSApp delegate] window]
                      modalDelegate:nil
                     didEndSelector:nil
                        contextInfo:nil];
  }];

  [conn setHermesProxy];
  [conn start];
  [spinner setHidden:NO];
}

@end
