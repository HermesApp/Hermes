#ifndef CRYPT_H
#define CRYPT_H

NSData* PandoraEncryptData(NSData* string, NSString *encryptionKey);
NSData* PandoraDecryptString(NSString* string, NSString *decryptionKey);

#endif /* CRYPT_H */
