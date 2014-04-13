/**
 * @file Pandora/Crypt.h
 * @brief Implementation of the encryption/decryption of requests to/from
 *        Pandora
 *
 * The encryption algorithm used is Blowfish in ECB mode.
 */

#ifndef CRYPT_H
#define CRYPT_H

/**
 * @brief Encrypt some data for Pandora
 *
 * @param data the data to encrypt
 * @param encryptionKey the encryption key to use
 * @return the encrypted data, hex encoded
 */
NSData* PandoraEncryptData(NSData* string, NSString *encryptionKey);

/**
 * @brief Decrypt some data received from Pandora
 *
 * @param string the hex-encoded string to be decrypted.
 * @param decryptionKey the decryption key to use
 * @return the decrypted data
 */
NSData* PandoraDecryptString(NSString* string, NSString *decryptionKey);

#endif /* CRYPT_H */
