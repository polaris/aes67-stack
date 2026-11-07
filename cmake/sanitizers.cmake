# AddressSanitizer + UndefinedBehaviorSanitizer for host builds.
# Usage: aes67_enable_sanitizers(<target>)
# Active only when AES67_ENABLE_SANITIZERS is ON.

function(aes67_enable_sanitizers target)
    if(NOT AES67_ENABLE_SANITIZERS)
        return()
    endif()
    set(flags -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
    target_compile_options(${target} PRIVATE ${flags})
    target_link_options(${target} PUBLIC ${flags})
endfunction()
