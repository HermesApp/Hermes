//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#pragma once

#define KEYCHAIN_SERVICE_NAME "Hermes"

BOOL KeychainSetItem(NSString* username, NSString *password);
NSString* KeychainGetPassword(NSString *username);
