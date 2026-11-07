# libFuzzer targets: tests/fuzz/fuzz_<module>.c -> fuzz_<module>
# Each file defines LLVMFuzzerTestOneInput().
# Run e.g.: ./build/host-fuzz/tests/fuzz/fuzz_sdp -max_total_time=600

function(aes67_add_fuzz_target source)
    get_filename_component(name "${source}" NAME_WE)
    add_executable(${name} "${source}")
    set_target_properties(${name} PROPERTIES
        C_STANDARD 11
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS OFF)
    target_link_libraries(${name} PRIVATE aes67::core)
    target_compile_options(${name} PRIVATE -fsanitize=fuzzer)
    target_link_options(${name} PRIVATE -fsanitize=fuzzer)
    aes67_set_warnings(${name})
    aes67_enable_sanitizers(${name})
endfunction()

# The core itself needs coverage instrumentation for libFuzzer.
target_compile_options(aes67_core PRIVATE -fsanitize=fuzzer-no-link)

file(GLOB AES67_FUZZ_TARGETS CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/fuzz_*.c")

foreach(fuzz_source IN LISTS AES67_FUZZ_TARGETS)
    aes67_add_fuzz_target("${fuzz_source}")
endforeach()
