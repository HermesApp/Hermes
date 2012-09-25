//
//  HistoryItem.h
//  Hermes
//
//  Created by Alex Crichton on 10/10/11.
//

@interface HistoryItem : NSCollectionViewItem {
  NSButton *like;
  NSButton *dislike;
  NSButton *art;
}

- (IBAction) like:(id)sender;
- (IBAction) dislike:(id)sender;
- (IBAction) gotoArtist:(id)sender;
- (IBAction) gotoAlbum:(id)sender;
- (IBAction) gotoTitle:(id)sender;

@end
