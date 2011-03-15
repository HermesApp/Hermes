
#define KEYCHAIN_GENERIC_ATTR "application password"
#define KEYCHAIN_LABEL_ATTR "Hermes"

@interface Keychain : NSObject {

}

+ (BOOL) setKeychainItem: (NSString*)username : (NSString*)password;
+ (NSString*) getKeychainPassword: (NSString*)username;

@end
