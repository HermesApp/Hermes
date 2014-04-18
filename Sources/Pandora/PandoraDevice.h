//
//  PandoraDevice.h
//  Hermes
//
//  Created by Winston Weinert on 4/18/14.
//
//


extern NSString * const kPandoraDeviceUsername;
extern NSString * const kPandoraDevicePassword;
extern NSString * const kPandoraDeviceDeviceID;
extern NSString * const kPandoraDeviceEncrypt;
extern NSString * const kPandoraDeviceDecrypt;
extern NSString * const kPandoraDeviceAPIHost;


@interface PandoraDevice : NSObject

+ (NSDictionary *)iPhone;
+ (NSDictionary *)android;
+ (NSDictionary *)desktop;

@end