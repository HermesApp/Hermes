//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "Keychain.h"

#import <Security/Security.h>

BOOL KeychainSetItem(NSString* username, NSString* password) {
  SecKeychainItemRef item;
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
    return result == noErr;
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

    return result == noErr;
  }
}

NSString *KeychainGetPassword(NSString* username) {
  void *password = NULL;
  UInt32 length;
  OSStatus result = SecKeychainFindGenericPassword(
    NULL,
    strlen(KEYCHAIN_SERVICE_NAME),
    KEYCHAIN_SERVICE_NAME,
    [username length],
    [username UTF8String],
    &length,
    &password,
    NULL);

  if (result != noErr) {
    return nil;
  }
  
  NSString *ret = [[NSString alloc] initWithBytes:password
                                           length:length
                                         encoding:NSUTF8StringEncoding];
  SecKeychainItemFreeContent(NULL, password);

  return ret;
}
