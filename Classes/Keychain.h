
@interface Keychain : NSObject {

}

+ (BOOL) setKeychainItem: (NSString*)username : (NSString*)password;
+ (NSString*) getKeychainPassword: (NSString*)username;

@end
