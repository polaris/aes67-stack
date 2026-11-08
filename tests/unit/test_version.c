#include "aes67/version.h"
#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

static void test_version_matches_macros(void)
{
    uint32_t version = aes67_version();
    uint32_t pad = (version >> 24) & 0xFFu;
    uint32_t major = (version >> 16) & 0xFFu;
    uint32_t minor = (version >> 8) & 0xFFu;
    uint32_t patch = version & 0xFFu;

    TEST_ASSERT_EQUAL_HEX32(0, pad);
    TEST_ASSERT_EQUAL_HEX32(AES67_VERSION_MAJOR, major);
    TEST_ASSERT_EQUAL_HEX32(AES67_VERSION_MINOR, minor);
    TEST_ASSERT_EQUAL_HEX32(AES67_VERSION_PATCH, patch);
}

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_version_matches_macros);
    return UNITY_END();
}
