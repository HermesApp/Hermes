#define KEYCHAIN_SERVICE_NAME "Hermes"

@interface KeychainException : NSException
@end

BOOL KeychainSetItem(NSString* username, NSString *password);
NSString* KeychainGetPassword(NSString *username);