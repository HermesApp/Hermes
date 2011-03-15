//
//  MainController.m
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import "MainController.h"
#import "Pandora.h"
#import "Keychain.h"
#import "HermesAppDelegate.h"

@implementation MainController

- (id) init {
  pandora = [[Pandora alloc] init];
  return self;
}

/* Part of the NSTableViewDataSource protocol */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [[pandora stations] count];
}

/* Part of the NSTableViewDataSource protocol */
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex {

  return [[[pandora stations] objectAtIndex: rowIndex] name];
}

/* Called whenever the playing stream changes state */
- (void)playbackStateChanged: (NSNotification *)aNotification {
  AudioStreamer *streamer = [playing stream];

  [playpause setImage:[NSImage imageNamed:@"play.png"]];

  if ([streamer isWaiting]) {
    NSLog(@"Waiting...");
  } else if ([streamer isPlaying]) {
    NSLog(@"Playing...");
    [playpause setImage:[NSImage imageNamed:@"pause.png"]];
  } else if ([streamer isIdle]) {
    NSLog(@"Idle...");
  }
}

/* Re-draws the timer counting up the time of the played song */
- (void)updateProgress: (NSTimer *)updatedTimer {
  AudioStreamer *streamer = [playing stream];

//  if (streamer.bitRate != 0.0) {
    int prog = streamer.progress;
    int dur = streamer.duration;

    if (dur > 0) {
      [progressLabel setStringValue:
        [NSString stringWithFormat:@"%d:%02d/%d:%02d",
         prog / 60, prog % 60, dur / 60, dur % 60]];
      [playbackProgress setDoubleValue:100 * prog / dur];
    } else {
//      [progress setEnabled:NO];
    }
//  } else {
//    [progressLabel setStringValue: @"What?"];
//    [positionLabel setStringValue:@"Time Played:"];
//  }
}

/* Called whenever a song starts playing, updates all fields to reflect that the song is
 * playing */
- (void)songPlayed: (NSNotification *)aNotification {
  Song *song = [playing playing];
  if (song == nil) {
    return;
  }

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(playbackStateChanged:)
    name:ASStatusChangedNotification
    object:[playing stream]];

  progressUpdateTimer =
    [NSTimer
     scheduledTimerWithTimeInterval:.3
     target:self
     selector:@selector(updateProgress:)
     userInfo:nil
     repeats:YES];

  if (song != nil) {
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:
        [NSURL URLWithString: song.art]];
    [image autorelease];

    [art setImage: image];
    [songLabel setStringValue: song.title];
    [artistLabel setStringValue: song.artist];
    [playbackProgress setDoubleValue: 0];
  }
}

/* Auth button hit */
- (IBAction) auth: (id)sender {
  [[NSApp delegate] showAuthSheet];
}

/* Authenticates a user with a username and password. If successful,
 * the username/password are stored in NSUserDefaults and the keychain
 */
- (BOOL) authenticate: (NSString*) username : (NSString*) password {
  if (![pandora authenticate: username : password]) {
    return NO;
  }

  [[NSUserDefaults standardUserDefaults] setObject:username forKey:USERNAME_KEY];
  [Keychain setKeychainItem:username : password];

  [pandora fetchStations];
  [stationsTable setDataSource: self];
  [stationsTable reloadData];

  for (Station *station in [pandora stations]) {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(songPlayed:)
     name:@"song.playing"
     object:station];
  }

  [stations toggle: nil];
  [auth setHidden:YES];
  [selectStation setHidden:NO];

  return YES;
}

- (IBAction)tableViewSelected: (id)sender {
  Station *selected = nil;

  int row = [stationsTable selectedRow];

  if (row != -1) {
    selected = [[pandora stations] objectAtIndex:row];
  }

  if (selected != playing && playing != nil) {
    NSLog(@"Don't do that");
    return;
  } else if (selected == playing) {
    return;
  }

  if (playing == nil) {
    [selectStation setHidden:YES];
    [art setHidden:NO];
    [artistLabel setHidden:NO];
    [songLabel setHidden:NO];
    [playbackProgress setHidden:NO];
    [progressLabel setHidden:NO];
  }

  playing = selected;
  [playing play];
  [songLoadingProgress setHidden:NO];
}

- (IBAction)playpause: (id) sender {
  if ([[playing stream] isPlaying]) {
    [playing pause];
  } else {
    [playing play];
  }
}

- (IBAction)next: (id) sender {
  NSLog(@"next");
  [playing next];
}

@end
