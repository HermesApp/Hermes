
#import "Keychain.h"

#import <Security/Security.h>

BOOL KeychainLogError(OSStatus status) {
  if (status == noErr) {
    return TRUE;
  } else {
    CFStringRef error = SecCopyErrorMessageString(status, NULL);
    NSLog(@"Keychain error: %@", error);
    CFRelease(error);
    return FALSE;
  }
}

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
    return KeychainLogError(result);
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

    return KeychainLogError(result);
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
    KeychainLogError(result);
    return nil;
  }

  NSString *ret = [[NSString alloc] initWithBytes:password length:length encoding:NSUTF8StringEncoding];
  SecKeychainItemFreeContent(NULL, password);
  [ret autorelease];

  return ret;
}
