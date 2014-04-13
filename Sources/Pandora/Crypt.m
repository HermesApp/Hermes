#include "blowfish/blowfish.h"

#import "Crypt.h"

/* Conversion from hex to int and int to hex */
static char i2h[16] = "0123456789abcdef";
static char h2i[256] = {
  ['0'] = 0, ['1'] = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6,
  ['7'] = 7, ['8'] = 8, ['9'] = 9, ['a'] = 10, ['b'] = 11, ['c'] = 12,
  ['d'] = 13, ['e'] = 14, ['f'] = 15
};

static void appendByte(unsigned char byte, void *_data) {
  NSMutableData *data = (__bridge NSMutableData *)_data;
  [data appendBytes:&byte length:1];
}

static void appendHex(unsigned char byte, void *_data) {
  NSMutableData *data = (__bridge NSMutableData *)_data;
  char bytes[2];
  bytes[1] = i2h[byte % 16];
  bytes[0] = i2h[byte / 16];
  [data appendBytes:bytes length:2];
}

NSData* PandoraDecryptString(NSString *string, NSString *decryptionKey) {
  struct blf_ecb_ctx ctx;
  NSMutableData *mut = [[NSMutableData alloc] init];
  const char *key = decryptionKey.UTF8String;
  
  Blowfish_ecb_start(&ctx, FALSE, (unsigned char *)key,
                     sizeof(key) - 1, appendByte,
                     (__bridge void *)mut);

  const char *bytes = [string cStringUsingEncoding:NSASCIIStringEncoding];
  int len = [string lengthOfBytesUsingEncoding:NSASCIIStringEncoding];
  for (int i = 0; i < len; i += 2) {
    Blowfish_ecb_feed(&ctx, h2i[(int) bytes[i]] * 16 + h2i[(int) bytes[i + 1]]);
  }
  Blowfish_ecb_stop(&ctx);

  return mut;
}

NSData* PandoraEncryptData(NSData *data, NSString *encryptionKey) {
  struct blf_ecb_ctx ctx;
  NSMutableData *mut = [[NSMutableData alloc] init];
  const char *key = encryptionKey.UTF8String;

  Blowfish_ecb_start(&ctx, TRUE, (unsigned char*)key,
                     sizeof(key) - 1, appendHex,
                     (__bridge void*)mut);

  const char *bytes = [data bytes];
  int len = [data length];
  for (int i = 0; i < len; i++) {
    Blowfish_ecb_feed(&ctx, bytes[i]);
  }
  Blowfish_ecb_stop(&ctx);

  return mut;
}
