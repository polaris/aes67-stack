#include "aes67/version.h"

uint32_t aes67_version(void)
{
    return ((uint32_t)AES67_VERSION_MAJOR << 16) | ((uint32_t)AES67_VERSION_MINOR << 8) |
           (uint32_t)AES67_VERSION_PATCH;
}
