cmake_minimum_required(VERSION 3.25)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(aes67-version)
include(warnings)
include(sanitizers)

aes67_read_version("${CMAKE_CURRENT_SOURCE_DIR}/include/aes67/version.h" AES67_VERSION)

project(aes67_stack
    VERSION ${AES67_VERSION}
    DESCRIPTION "Portable AES67 stack in C11"
    LANGUAGES C)

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
option(AES67_BUILD_TESTS "Build unit tests (Unity)" ON)
option(AES67_BUILD_APPS "Build POSIX command-line apps" ON)
option(AES67_BUILD_FUZZ "Build libFuzzer targets (Clang only)" OFF)
option(AES67_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(AES67_ENABLE_SANITIZERS "Build with AddressSanitizer and UBSan" OFF)
option(AES67_INSTALL "Generate install rules" ${PROJECT_IS_TOP_LEVEL})

# ---------------------------------------------------------------------------
# Core library: portable, no OS, no malloc
# ---------------------------------------------------------------------------
file(GLOB AES67_CORE_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/core/*.c")

add_library(aes67_core STATIC ${AES67_CORE_SOURCES})
add_library(aes67::core ALIAS aes67_core)

include(GNUInstallDirs)

target_include_directories(aes67_core PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")

set_target_properties(aes67_core PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    C_EXTENSIONS OFF
    EXPORT_NAME core)

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
    # The core itself needs coverage instrumentation for libFuzzer.
    target_compile_options(aes67_core PRIVATE -fsanitize=fuzzer-no-link)
    add_subdirectory(tests/fuzz)
endif()

if(AES67_BUILD_APPS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/apps/CMakeLists.txt")
    add_subdirectory(apps)
endif()

# ---------------------------------------------------------------------------
# Install configuration
# ---------------------------------------------------------------------------
if(AES67_INSTALL)
    set(AES67_INSTALL_CMAKE_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/aes67")

    install(TARGETS aes67_core EXPORT aes67Targets
            ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    install(EXPORT aes67Targets
            NAMESPACE aes67::
            DESTINATION "${AES67_INSTALL_CMAKE_DIR}")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/aes67"
            DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

    include(CMakePackageConfigHelpers)

    configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/aes67Config.cmake.in" "${CMAKE_CURRENT_BINARY_DIR}/aes67Config.cmake"
        INSTALL_DESTINATION "${AES67_INSTALL_CMAKE_DIR}")

    write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/aes67ConfigVersion.cmake"
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY SameMinorVersion)

    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/aes67Config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/aes67ConfigVersion.cmake"
            DESTINATION "${AES67_INSTALL_CMAKE_DIR}")
endif()
