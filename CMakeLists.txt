cmake_minimum_required(VERSION 3.25)

project(aes67_stack
    VERSION 0.1.0
    DESCRIPTION "Portable AES67 stack in C11"
    LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(warnings)
include(sanitizers)

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
option(AES67_BUILD_TESTS "Build unit tests (Unity)" ON)
option(AES67_BUILD_APPS "Build POSIX command-line apps" ON)
option(AES67_BUILD_FUZZ "Build libFuzzer targets (Clang only)" OFF)
option(AES67_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(AES67_ENABLE_SANITIZERS "Build with AddressSanitizer and UBSan" OFF)

# ---------------------------------------------------------------------------
# Core library: portable, no OS, no malloc
# ---------------------------------------------------------------------------
file(GLOB AES67_CORE_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/core/*.c")

add_library(aes67_core STATIC ${AES67_CORE_SOURCES})
add_library(aes67::core ALIAS aes67_core)

target_include_directories(aes67_core
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")

set_target_properties(aes67_core PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    C_EXTENSIONS OFF)

aes67_set_warnings(aes67_core)
aes67_enable_sanitizers(aes67_core)

# ---------------------------------------------------------------------------
# Optional parts (not built for the MCU target)
# ---------------------------------------------------------------------------
if(AES67_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests/unit)
endif()

if(AES67_BUILD_FUZZ)
    if(NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
        message(FATAL_ERROR "AES67_BUILD_FUZZ requires Clang (libFuzzer)")
    endif()
    add_subdirectory(tests/fuzz)
endif()

if(AES67_BUILD_APPS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/apps/CMakeLists.txt")
    add_subdirectory(apps)
endif()
