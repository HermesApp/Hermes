#import "Keychain.h"

#import <Security/Security.h>

@implementation KeychainException
@end 

BOOL KeychainHandleError(OSStatus status) {
  if (status == noErr) {
    return TRUE;
  } else {
    NSString *error = (__bridge NSString*) SecCopyErrorMessageString(status, NULL);
    @throw [KeychainException exceptionWithName:@"Keychain Error"
                                         reason:error
                                       userInfo:nil];
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
    return KeychainHandleError(result);
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

    return KeychainHandleError(result);
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
    KeychainHandleError(result);
    return nil;
  }

  NSString *ret = [[NSString alloc] initWithBytes:password length:length encoding:NSUTF8StringEncoding];
  SecKeychainItemFreeContent(NULL, password);

  return ret;
}
