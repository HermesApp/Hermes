//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#pragma once

#define KEYCHAIN_SERVICE_NAME "Hermes"

/**
 * Set a password in the Login Keychain
 *
 * @param username the Keychain entry name to use.
 * @param password the password to store in the Keychain entry.
 * @return YES if Keychain entry was set, NO otherwise.
 */
BOOL KeychainSetItem(NSString* username, NSString *password);

/**
 * Get a password from the Login Keychain
 *
 * @param username the Keychain entry's name
 * @return the password stored in the entry
 */
NSString* KeychainGetPassword(NSString *username);
