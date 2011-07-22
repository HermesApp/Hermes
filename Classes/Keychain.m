
#import "Keychain.h"

#import <Security/Security.h>

BOOL KeychainSetItem(NSString* username, NSString* password) {
  return noErr == SecKeychainAddGenericPassword(
    NULL,
    strlen(KEYCHAIN_SERVICE_NAME),
    KEYCHAIN_SERVICE_NAME,
    [username length],
    [username UTF8String],
    [password length],
    [password UTF8String],
    NULL);
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
    SecKeychainItemFreeContent(NULL, password);
    return nil;
  }

  NSString *ret = [[NSString alloc] initWithBytes:password length:length encoding:NSUTF8StringEncoding];
  SecKeychainItemFreeContent(NULL, password);
  [ret autorelease];
  
  return ret;
}
