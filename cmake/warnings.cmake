# Strict warnings for every target of this project.
# Usage: aes67_set_warnings(<target>)

function(aes67_set_warnings target)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE
            -Wall
            -Wextra
            -Wpedantic
            -Wconversion
            -Wsign-conversion
            -Wshadow
            -Wcast-align
            -Wstrict-prototypes
            -Wmissing-prototypes
            -Wvla
            -Wdouble-promotion
            -Wformat=2
            -Wundef
            -Wnull-dereference)
        if(AES67_WARNINGS_AS_ERRORS)
            target_compile_options(${target} PRIVATE -Werror)
        endif()
    endif()
endfunction()
