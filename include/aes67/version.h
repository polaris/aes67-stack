#ifndef AES67_VERSION_H
#define AES67_VERSION_H

/**
 * @file version.h
 * @brief Library version. Placeholder module so that the scaffold builds and
 *        tests run before the real API is designed (phase 1, part B).
 */

#include <stdint.h>

#define AES67_VERSION_MAJOR 0
#define AES67_VERSION_MINOR 1
#define AES67_VERSION_PATCH 0

/**
 * @brief Return the library version packed as 0x00MMmmpp
 *        (major, minor, patch, one byte each).
 */
uint32_t aes67_version(void);

#endif /* AES67_VERSION_H */
