//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "Keychain.h"

#import <Security/Security.h>

BOOL KeychainSetItem(NSString* username, NSString* password) {
  SecKeychainItemRef item = nil;
  OSStatus result = SecKeychainFindGenericPassword(
    NULL,
    strlen(KEYCHAIN_SERVICE_NAME),
    KEYCHAIN_SERVICE_NAME,
    [username length],
    [username UTF8String],
    NULL,
    NULL,
    &item);

  if (result == noErr) {
    result = SecKeychainItemModifyContent(item, NULL, [password length],
                                          [password UTF8String]);
  } else {
    result = SecKeychainAddGenericPassword(
      NULL,
      strlen(KEYCHAIN_SERVICE_NAME),
      KEYCHAIN_SERVICE_NAME,
      [username length],
      [username UTF8String],
      [password length],
      [password UTF8String],
      NULL);
  }

  if (item) {
    CFRelease(item);
  }
  return result == noErr;
}

NSString *KeychainGetPassword(NSString* username) {
  void *passwordData = NULL;
  UInt32 length;
  OSStatus result = SecKeychainFindGenericPassword(
    NULL,
    strlen(KEYCHAIN_SERVICE_NAME),
    KEYCHAIN_SERVICE_NAME,
    [username length],
    [username UTF8String],
    &length,
    &passwordData,
    NULL);

  if (result != noErr) {
    return nil;
  }
  
  NSString *password = [[NSString alloc] initWithBytes:passwordData
                                           length:length
                                         encoding:NSUTF8StringEncoding];
  SecKeychainItemFreeContent(NULL, passwordData);

  return password;
}
