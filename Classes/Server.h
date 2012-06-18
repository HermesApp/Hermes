//
//  Server.h
//  Hermes
//
//  Created by Sheyne Anderson on 6/16/12.
//  Copyright (c) 2012 Sheyne Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

/*
 Socket Protocol:
    if server receives:
        "list stations"
            it should respond with a list of all stations. Each station should be transimited as: "station\0STATION_NAME\0STATION_ID\n" 
        "list playing"
             transmit:
                "name\0CURRENT_SONG_NAME\n"
                "artist\0CURRENT_ARTIST\n"
                "album\0CURRENT_ALBUM\n"
        "skip"
            skip currently playing song
        "play"
            play
        "pause"
            pause
        "playpause"
            toggle between playing and pausing
        "thumbs up"
            like current song
        "thumbs down"    
            dislike current song
    the server can also update station list at any time by sending stations in the format described under "list stations", it can also update currently playing song information in the method described under "list playing". 
 
Additonal Features to add:
    list playing state
    make list playing list whether the song is liked/disliked
    make list laying transmit a URL for album cover and song info
 */

@interface Server : NSObject
{
    GCDAsyncSocket *s;
}

-(void)beginListeningOnPort:(short)port;

-(void)postNotification:(NSString *)notification toSocket:(GCDAsyncSocket *)socket;

@end
