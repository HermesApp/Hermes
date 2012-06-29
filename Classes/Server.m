
//
//  Server.m
//  Hermes
//
//  Created by Sheyne Anderson on 6/16/12.
//  Copyright (c) 2012 Sheyne Anderson. All rights reserved.
//

#import "Server.h"
#import "PlaybackController.h"
#import "HermesAppDelegate.h"
#import "Pandora/Station.h"
#import "StationsController.h"

void readSocket(GCDAsyncSocket *s){
    [s readDataToData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag:0];
}

@implementation Server{
    NSMutableArray *connectedSockets;
}

-(id)init{
    if(self = [super init]){
        connectedSockets = [[NSMutableArray alloc] init];
        s = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(songPlayed:)
         name:@"song.playing"
         object:nil];

    }
    return self;
}

- (void) songPlayed:(NSNotification*) not {
    Song *playing = [[[[NSApp delegate] playback]playing] playing];
    [self postNotification:[NSString stringWithFormat:@"name\0%@", playing.title] toSocket:nil];
    [self postNotification:[NSString stringWithFormat:@"artist\0%@", playing.artist] toSocket:nil];
    [self postNotification:[NSString stringWithFormat:@"album\0%@", playing.album] toSocket:nil];
}


-(void)beginListeningOnPort:(short)port{
    if (s.isConnected)
        [s disconnect];
    [s acceptOnPort:port error:nil];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    [connectedSockets addObject:newSocket];
    readSocket(newSocket);
}

- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag
{
    readSocket(sender);
    NSString *command = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    command = [command stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    PlaybackController *playback = [[NSApp delegate] playback];
    NSArray *stations = [[[NSApp delegate] pandora] stations];
    
    if ([command isEqualToString:@"skip"]) {        
        [playback next:self];
    }else if ([command isEqualToString:@"play"]) {        
        [playback play];
    }else if ([command isEqualToString:@"pause"]) {        
        [playback pause];
    }else if ([command isEqualToString:@"playpause"]) {        
        [playback playpause:self];
    }else if ([command isEqualToString:@"thumbs up"]) {        
        [playback like:self];
    }else if ([command isEqualToString:@"thumbs down"]) {        
        [playback dislike:self];
    }else if ([command isEqualToString:@"list playing"]) {        
        [self songPlayed:nil];
    }else if ([command isEqualToString:@"list stations"]) {        
        [stations enumerateObjectsUsingBlock:^(Station *station, NSUInteger idx, BOOL *stop) {
            [self postNotification:[NSString stringWithFormat:@"station\0%@\0%@", station.name, station.stationId] toSocket:sender];
        }];
    }else if ([command hasPrefix:@"set station"]) {  
        NSArray *r = [[command stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsSeparatedByString:@"\0"];
        NSString *stationId = [r objectAtIndex:1];

        [stations enumerateObjectsUsingBlock:^(Station *station, NSUInteger idx, BOOL *stop) {
            if ([station.stationId isEqualToString:stationId]) {
                [playback playStation:station];
                StationsController *stat = ((HermesAppDelegate*)[NSApp delegate]).stations;
                [stat refreshList:self];
                *stop = YES;
            }
        }];
    }
}


-(void)postNotification:(NSString *)notification toSocket:(GCDAsyncSocket *)socket{
    if (socket == nil) {
        [connectedSockets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [self postNotification:notification toSocket:obj];
        }];
    }
    [socket writeData:[[notification stringByAppendingString:@"\n"] dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag:0];
}

+(id)sharedInstance{
    static id shared_server_inst;
    if (!shared_server_inst){
        shared_server_inst = [[Server alloc] init];
    }
    return shared_server_inst;
}

@end
