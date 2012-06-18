//
//  Server.h
//  Hermes
//
//  Created by Sheyne Anderson on 6/16/12.
//  Copyright (c) 2012 Sheyne Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface Server : NSObject
{
    GCDAsyncSocket *s;
}

-(void)beginListeningOnPort:(short)port;

-(void)postNotification:(NSString *)notification toSocket:(GCDAsyncSocket *)socket;

@end
