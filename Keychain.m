
#import "Keychain.h"

#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

@implementation Keychain

+ (void) initializeAttributes: (SecKeychainAttribute*) attributes
    username: (NSString*) username {

  attributes[0].tag    = kSecGenericItemAttr;
  attributes[0].data   = KEYCHAIN_GENERIC_ATTR;
  attributes[0].length = sizeof(KEYCHAIN_GENERIC_ATTR);

  attributes[1].tag    = kSecLabelItemAttr;
  attributes[1].data   = KEYCHAIN_LABEL_ATTR;
  attributes[1].length = sizeof(KEYCHAIN_LABEL_ATTR);

  attributes[2].tag    = kSecAccountItemAttr;
  attributes[2].data   = (void*) [username UTF8String];
  attributes[2].length = [username length];
}

+ (SecKeychainItemRef) keychainItemFor: (NSString*) username {
  SecKeychainSearchRef search;
  SecKeychainItemRef item;
  SecKeychainAttribute attributes[3];
  OSErr result;

  [self initializeAttributes: attributes username:username];

  SecKeychainAttributeList list = {3, attributes};

  result = SecKeychainSearchCreateFromAttributes(NULL,
      kSecGenericPasswordItemClass, &list, &search);

  if (result == noErr && SecKeychainSearchCopyNext (search, &item) != noErr) {
    item = NULL;
  }

  CFRelease (search);
  return item;
}

+ (SecKeychainItemRef) createKeychainItemFor: (NSString*) username
    password: (NSString*) password {
  SecKeychainAttribute attributes[3];
  SecKeychainAttributeList list;
  SecKeychainItemRef item;
  OSStatus status;

  [self initializeAttributes: attributes username:username];

  list.count = 3;
  list.attr  = attributes;

  status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &list,
    [password length], [password UTF8String], NULL, NULL, &item);

  if (status != 0) {
    item = NULL;
  }

  return item;
}

+ (BOOL) setKeychainItem: (NSString*)username : (NSString*)password {
  OSStatus status;
  BOOL ret = NO;
  SecKeychainAttribute attributes[1];

  attributes[0].tag    = kSecAccountItemAttr;
  attributes[0].data   = (void*) [username UTF8String];
  attributes[0].length = [username length];

  SecKeychainAttributeList list = {1, attributes};

  SecKeychainItemRef item = [self keychainItemFor: username];
  if (item == NULL) {
    item = [self createKeychainItemFor:username password:password];
    ret = (item != NULL);

    if (ret) {
      CFRelease(item);
    }

    return ret;
  }

  status = SecKeychainItemModifyContent (item, &list, [password length],
                                       [password UTF8String]);

  ret = (status == noErr);

  CFRelease(item);
  return ret;
}

+ (NSString*) getKeychainPassword: (NSString*)username {
  UInt32 length;
  char *password;
  OSStatus status;
  NSString *ret = nil;

  SecKeychainItemRef item = [self keychainItemFor: username];
  if (item == NULL) {
    return nil;
  }

  status = SecKeychainItemCopyContent (item, NULL, NULL, &length,
    (void**)&password);

  if (status == noErr) {
    ret = [[NSString alloc] initWithBytes:password
        length:length encoding:NSASCIIStringEncoding];
    [ret autorelease];
    SecKeychainItemFreeContent(NULL, password);
  }

  CFRelease(item);
  return ret;
}

@end
