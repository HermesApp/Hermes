//
//  HistoryController.h
//  Hermes
//
//  Created by Alex Crichton on 10/9/11.
//

@interface HistoryController : NSObject {
  IBOutlet NSWindow *history;
  IBOutlet NSCollectionView *collection;
  NSMutableArray *songs;
  NSArrayController *controller;
}

@property(retain, readwrite) IBOutlet NSMutableArray *songs;
@property(retain, readwrite) IBOutlet NSArrayController *controller;

- (void) addSong: (Song*) song;
- (BOOL) saveSongs;
- (IBAction) showHistory:(id)sender;
- (IBAction) closeHistory:(id)sender;

- (void) insertObject:(Song *)s inSongsAtIndex:(NSUInteger)index;
- (void) removeObjectFromSongsAtIndex:(NSUInteger)index;

@end
