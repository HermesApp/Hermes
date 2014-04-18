//
//  PandoraDevice.m
//  Hermes
//
//  Created by Winston Weinert on 4/18/14.
//
//

#import "PandoraDevice.h"


NSString * const kPandoraDeviceUsername = @"username";
NSString * const kPandoraDevicePassword = @"password";
NSString * const kPandoraDeviceDeviceID = @"deviceid";
NSString * const kPandoraDeviceEncrypt  = @"encrypt";
NSString * const kPandoraDeviceDecrypt  = @"decrypt";
NSString * const kPandoraDeviceAPIHost  = @"apihost";


@implementation PandoraDevice : NSObject

+ (NSDictionary *)iPhone {
  return @{
           kPandoraDeviceUsername: @"iphone",
           kPandoraDevicePassword: @"P2E4FC0EAD3*878N92B2CDp34I0B1@388137C",
           kPandoraDeviceDeviceID: @"IP01",
           kPandoraDeviceEncrypt:  @"721^26xE22776",
           kPandoraDeviceDecrypt:  @"20zE1E47BE57$51",
           kPandoraDeviceAPIHost:  @"tuner.pandora.com"
           };
}

+ (NSDictionary *)android {
  return @{
           kPandoraDeviceUsername: @"android",
           kPandoraDevicePassword: @"AC7IBG09A3DTSYM4R41UJWL07VLN8JI7",
           kPandoraDeviceDeviceID: @"android-generic",
           kPandoraDeviceEncrypt:  @"6#26FRL$ZWD",
           kPandoraDeviceDecrypt:  @"R=U!LH$O2B#",
           kPandoraDeviceAPIHost:  @"tuner.pandora.com"
           };
}

+ (NSDictionary *)desktop {
  return @{
           kPandoraDeviceUsername: @"pandora one",
           kPandoraDevicePassword: @"TVCKIBGS9AO9TSYLNNFUML0743LH82D",
           kPandoraDeviceDeviceID: @"D01",
           kPandoraDeviceEncrypt:  @"2%3WCL*JU$MP]4",
           kPandoraDeviceDecrypt:  @"U#IO$RZPAB%VX2",
           kPandoraDeviceAPIHost:  @"internal-tuner.pandora.com"
           };
}

@end
