function(aes67_read_version header out_var)
    if(NOT EXISTS "${header}")
        message(FATAL_ERROR "Version header not found: ${header}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${header}")

    set(version_list "")
    foreach(ident AES67_VERSION_MAJOR AES67_VERSION_MINOR AES67_VERSION_PATCH)
        file(STRINGS "${header}" line REGEX "^#define[ \t]+${ident}[ \t]")

        if(line STREQUAL "")
            message(FATAL_ERROR
                "${ident} not found in ${header}\n"
                "Expected a line like: #define ${ident} 1")
        endif()

        string(REGEX MATCH "^#define[ \t]+${ident}[ \t]+([0-9]+)" _ "${line}")
        if(CMAKE_MATCH_1 STREQUAL "")
            message(FATAL_ERROR
                "${ident} in ${header} has no numeric value.\n"
                "Found line: ${line}")
        endif()

        list(APPEND version_list "${CMAKE_MATCH_1}")
    endforeach()

    list(JOIN version_list "." version)
    set(${out_var} "${version}" PARENT_SCOPE)
endfunction()
