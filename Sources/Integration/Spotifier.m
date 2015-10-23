//
//  SpotifyURLOpener.m
//  Hermes
//
//  Created by Sheyne Anderson on 10/23/15.
//
//

#import "Spotifier.h"
#import "PlaybackController.h"

@implementation Spotifier

-(void)openCurrentSong:(id)sender{
    [self openSpotifyWithSong: [[[NSApp delegate] playback] playing].playingSong];
}
-(void)openSpotifyWithSong:(Song *)song{
    NSString *artist = song.artist;
    NSString *album = song.album;
    NSString *track = song.title;
    
    NSString *url = [NSString stringWithFormat:@"spotify:search:%@+%@+%@", artist, album, track];
    url = [url stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    url = [url stringByReplacingOccurrencesOfString:@"(Explicit)" withString:@"+"];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}
@end
