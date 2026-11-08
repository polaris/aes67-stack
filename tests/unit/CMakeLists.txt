include(FetchContent)

# Unity test framework (ThrowTheSwitch), pinned to a release tag.
FetchContent_Declare(unity
    GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
    GIT_TAG v2.6.1
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(unity)

# One executable per test file: tests/unit/test_<module>.c -> test_<module>
# Each file has its own main() that calls UNITY_BEGIN/RUN_TEST/UNITY_END.
function(aes67_add_unit_test source)
    get_filename_component(name "${source}" NAME_WE)
    add_executable(${name} "${source}")
    set_target_properties(${name} PROPERTIES
        C_STANDARD 11
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS OFF)
    target_link_libraries(${name} PRIVATE aes67::core unity)
    target_compile_definitions(${name} PRIVATE
        AES67_TEST_DATA_DIR="${PROJECT_SOURCE_DIR}/tests/data")
    aes67_set_warnings(${name})
    aes67_enable_sanitizers(${name})
    add_test(NAME ${name} COMMAND ${name})
endfunction()

file(GLOB AES67_UNIT_TESTS CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/test_*.c")

foreach(test_source IN LISTS AES67_UNIT_TESTS)
    aes67_add_unit_test("${test_source}")
endforeach()
