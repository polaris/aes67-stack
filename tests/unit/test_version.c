#include "aes67/version.h"
#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

static void test_version_matches_macros(void)
{
    TEST_ASSERT_EQUAL_HEX32(0x000100u, aes67_version());
}

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_version_matches_macros);
    return UNITY_END();
}
