//
//  HistoryController.h
//  Hermes
//
//  Created by Alex Crichton on 10/9/11.
//

@class FileReader;
@class Song;

@interface HistoryController : NSObject {
  IBOutlet NSWindow *history;
  IBOutlet NSCollectionView *collection;
  FileReader *reader;

  IBOutlet NSButton *like;
  IBOutlet NSButton *dislike;
  IBOutlet NSDrawer *drawer;
  IBOutlet NSProgressIndicator *spinner;
}

@property IBOutlet NSMutableArray *songs;
@property IBOutlet NSArrayController *controller;

- (void) showDrawer;
- (void) hideDrawer;

- (void) addSong: (Song*) song;
- (BOOL) saveSongs;

- (void) insertObject:(Song *)s inSongsAtIndex:(NSUInteger)index;
- (void) removeObjectFromSongsAtIndex:(NSUInteger)index;

- (void) selectionChanged;
- (IBAction) likeSelected:(id)sender;
- (IBAction) dislikeSelected:(id)sender;
- (IBAction) gotoArtist:(id)sender;
- (IBAction) gotoSong:(id)sender;
- (IBAction) gotoAlbum:(id)sender;
- (IBAction) showLyrics:(id)sender;

@end
