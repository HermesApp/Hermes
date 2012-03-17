/**
 * @file Keys.h
 * @brief Exports symbols for the encryption keys that Pandora uses
 */

#ifndef _KEYS_H
#define _KEYS_H

extern unsigned int OutputKey_n;
extern unsigned int OutputKey_p[];
extern unsigned int OutputKey_s[4][256];

extern unsigned int InputKey_n;
extern unsigned int InputKey_p[];
extern unsigned int InputKey_s[4][256];

#endif /* _KEYS_H */