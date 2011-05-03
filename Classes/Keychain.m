
#import "Keychain.h"

#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>


void KeychaininitializeAttributes(SecKeychainAttribute* attributes, NSString *username) {
  attributes[0].tag    = kSecGenericItemAttr;
  attributes[0].data   = KEYCHAIN_GENERIC_ATTR;
  attributes[0].length = sizeof(KEYCHAIN_GENERIC_ATTR);

  attributes[1].tag    = kSecLabelItemAttr;
  attributes[1].data   = KEYCHAIN_LABEL_ATTR;
  attributes[1].length = sizeof(KEYCHAIN_LABEL_ATTR);

  attributes[2].tag    = kSecAccountItemAttr;
  attributes[2].data   = (void*) [username cStringUsingEncoding:NSUTF8StringEncoding];
  attributes[2].length = [username length];
}

SecKeychainItemRef KeychainItemFor(NSString* username) {
  SecKeychainSearchRef search;
  SecKeychainItemRef item = NULL;
  SecKeychainAttribute attributes[3];
  OSErr result;

  KeychaininitializeAttributes(attributes, username);

  SecKeychainAttributeList list = {3, attributes};

  result = SecKeychainSearchCreateFromAttributes(NULL,
      kSecGenericPasswordItemClass, &list, &search);

  if (result == noErr) {
    result = SecKeychainSearchCopyNext(search, &item);

    if (result != noErr) {
      item = NULL;
    }
  }

  if (search)
    CFRelease(search);

  return item;
}

SecKeychainItemRef KeychainCreateItemFor(NSString* username, NSString* password) {
  SecKeychainAttribute attributes[3];
  SecKeychainAttributeList list;
  SecKeychainItemRef item = NULL;
  OSStatus status;

  KeychaininitializeAttributes(attributes, username);

  list.count = 3;
  list.attr  = attributes;

  status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &list,
    [password length], [password cStringUsingEncoding:NSUTF8StringEncoding],
    NULL, NULL, &item);

  if (status != 0) {
    item = NULL;
  }

  return item;
}

BOOL KeychainSetItem(NSString* username, NSString* password) {
  OSStatus status;
  BOOL ret = NO;
  SecKeychainAttribute attributes[1];

  attributes[0].tag    = kSecAccountItemAttr;
  attributes[0].data   = (void*) [username cStringUsingEncoding:NSUTF8StringEncoding];
  attributes[0].length = [username length];

  SecKeychainAttributeList list = {1, attributes};

  SecKeychainItemRef item = KeychainItemFor(username);
  if (item == NULL) {
    item = KeychainCreateItemFor(username, password);
    ret = (item != NULL);

    if (ret) {
      CFRelease(item);
    }

    return ret;
  }

  status = SecKeychainItemModifyContent(item, &list, [password length],
                          [password cStringUsingEncoding:NSUTF8StringEncoding]);

  ret = (status == noErr);

  CFRelease(item);
  return ret;
}

NSString *KeychainGetPassword(NSString* username) {
  UInt32 length;
  char *password;
  OSStatus status;
  NSString *ret = nil;

  SecKeychainItemRef item = KeychainItemFor(username);
  if (item == NULL) {
    return nil;
  }

  status = SecKeychainItemCopyContent (item, NULL, NULL, &length,
    (void**)&password);

  if (status == noErr) {
    ret = [[NSString alloc] initWithBytes:password
        length:length encoding:NSUTF8StringEncoding];
    [ret autorelease];
    SecKeychainItemFreeContent(NULL, password);
  }

  CFRelease(item);
  return ret;
}
