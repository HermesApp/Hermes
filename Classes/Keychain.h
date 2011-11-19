#pragma once

#define KEYCHAIN_SERVICE_NAME "Hermes"

BOOL KeychainSetItem(NSString* username, NSString *password);
NSString* KeychainGetPassword(NSString *username);
