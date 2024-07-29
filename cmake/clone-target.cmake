#
# The MIT License (MIT)
#
# Copyright (c) 2024 Steffen Nuessle
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

function(_get_target_property_detail VARIABLE TARGET PROPERTY)
    get_target_property(
        ${VARIABLE}
        ${TARGET}
        ${PROPERTY}
    )

    if ("${${VARIABLE}}" STREQUAL "${VARIABLE}-NOTFOUND")
        set(${VARIABLE})
    endif()

    set(${VARIABLE} ${${VARIABLE}} PARENT_SCOPE)
endfunction()

#
# clone_target
#
function(clone_target ARG_NAME)
    set(
        FLAG_ARGS
        EXCLUDE_FROM_ALL
        USE_RSP_FILE
    )

    set(
        ONE_VALUE_ARGS
        OUTPUT_DEPS
        OUTPUT_OBJS
        PRIMARY
        RESPONSE_FILE_FLAG
    )

    set(
        MULTI_VALUE_ARGS
        CC
        CXX
        LD
        INCLUDE_FLAGS_ARGS
        COMPILE_DEFINITONS
        COMPILE_OPTIONS
        COMPILE_RULE
        LINK_RULE
        C_STANDARD
        CXX_STANDARD
        LINK_OPTIONS
        LINK_LIBRARIES
    )

    cmake_parse_arguments(
        ARG
        "${FLAG_ARGS}"
        "${ONE_VALUE_ARGS}"
        "${MULTI_VALUE_ARGS}"
        ${ARGN}
    )

    if (NOT DEFINED ARG_PRIMARY)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "variable PRIMARY not set - a target for cloning must be specified"
        )
    endif()

    if (DEFINED ARG_CC)
        set(CT_C_COMPILER ${ARG_NAME}_CT_C_COMPILER)

        find_program(${CT_C_COMPILER} ${ARG_CC} REQUIRED)
    endif()

    if (DEFINED ARG_CXX)
        set(CT_CXX_COMPILER ${ARG_NAME}_CT_CXX_COMPILER)

        find_program(${CT_CXX_COMPILER} ${ARG_CXX} REQUIRED)
    endif()

    if (DEFINED ARG_LD)
        set(CT_LINKER ${ARG_NAME}_CT_LINKER)

        find_program(${CT_LINKER} ${ARG_LD} REQUIRED)
    else()
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "variable LD not set - linker must be specified"
        )
    endif()

    if (NOT DEFINED ARG_RESPONSE_FILE_FLAG)
        set(ARG_RESPONSE_FILE_FLAG "@")
    endif()

    set(
        OUTPUT_DIRECTORY
        ${CMAKE_CURRENT_BINARY_DIR}/CloneTargetFiles/${ARG_NAME}
    )

    if (NOT DEFINED ARG_COMPILE_RULE)
        set(
            ARG_COMPILE_RULE
            <COMPILER>
            -MMD
            -MT <OBJECT>
            -MF <DEPFILE>
            <DEFINES>
            <INCLUDES>
            <FLAGS>
            -c <INPUT>
            -o <OBJECT>
        )
    endif()

    if (NOT DEFINED ARG_LINK_RULE)
        set(
            ARG_LINK_RULE
            <LINKER>
            <OPTIONS>
            <OBJECTS>
            <LIBRARIES>
            -o <OUTPUT>
        )
    endif()

    get_target_property(
        PRIMARY_SOURCES
        ${ARG_PRIMARY}
        SOURCES
    )

    _get_target_property_detail(
        PRIMARY_CC_LAUNCHER
        ${ARG_PRIMARY}
        C_COMPILER_LAUNCHER
    )

    _get_target_property_detail(
        PRIMARY_CXX_LAUNCHER
        ${ARG_PRIMARY}
        CXX_COMPILER_LAUNCHER
    )

    if (NOT DEFINED ARG_COMPILE_DEFINITIONS_ARGS)
        _get_target_property_detail(
            ARG_COMPILE_DEFINITIONS_ARGS
            ${ARG_PRIMARY}
            COMPILE_DEFINITIONS
        )

        list(TRANSFORM ARG_COMPILE_DEFINITIONS_ARGS PREPEND "-D")
    endif()

    if (NOT DEFINED ARG_INCLUDE_FLAGS_ARGS)
        _get_target_property_detail(
            ARG_INCLUDE_FLAGS_ARGS
            ${ARG_PRIMARY}
            INCLUDE_DIRECTORIES
        )

        list(TRANSFORM ARG_INCLUDE_FLAGS_ARGS PREPEND "-I")
    endif()

    if (NOT DEFINED ARG_COMPILE_OPTIONS)
        _get_target_property_detail(
            ARG_COMPILE_OPTIONS
            ${ARG_PRIMARY}
            COMPILE_OPTIONS
        )
    endif()

    if (NOT DEFINED ARG_C_STANDARD)
        _get_target_property_detail(
            ARG_C_STANDARD
            ${ARG_PRIMARY}
            C_STANDARD
        )

        if (ARG_C_STANDARD)
            set(ARG_C_STANDARD "-std=c${ARG_C_STANDARD}")
        endif()
    endif()

    if (NOT DEFINED ARG_CXX_STANDARD)
        _get_target_property_detail(
            ARG_CXX_STANDARD
            ${ARG_PRIMARY}
            CXX_STANDARD
        )

        if (ARG_CXX_STANDARD)
            set(ARG_CXX_STANDARD "-std=c++${ARG_CXX_STANDARD}")
        endif()
    endif()

    _get_target_property_detail(
        PRIMARY_JOB_POOL_COMPILE
        ${ARG_PRIMARY}
        JOB_POOL_COMPILE
    )

    if (PRIMARY_JOB_POOL_COMPILE)
        set(OPTION_JOB_POOL_COMPILE JOB_POOL ${PRIMARY_JOB_POOL_COMPILE})
    endif()

    unset(OBJ_FILES)
    unset(DEP_FILES)

    foreach(SRC_FILE ${PRIMARY_SOURCES})
        cmake_path(
            ABSOLUTE_PATH SRC_FILE
            BASE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            NORMALIZE
        )

        string(SHA1 SRC_HASH ${SRC_FILE})

        set(OBJ_DIR ${OUTPUT_DIRECTORY}/${SRC_HASH})

        cmake_path(GET SRC_FILE STEM SRC_STEM)
        cmake_path(GET SRC_FILE EXTENSION SRC_EXT)

        string(TOLOWER ${SRC_EXT} SRC_EXT)

        if ("${SRC_EXT}" STREQUAL ".c")
            set(TARGET_USES_C TRUE)
            set(SOURCE_LANG C)
            set(COMPILER_LAUNCHER ${PRIMARY_CC_LAUNCHER})
            set(COMPILER ${${CT_C_COMPILER}})
            set(OBJ_EXT ${CMAKE_C_OUTPUT_EXTENSION})
            set(LANGUAGE_STANDARD_ARG ${ARG_C_STANDARD})
        elseif ("${SRC_EXT}" MATCHES "\.c(c|pp|xx)")
            set(TARGET_USES_CXX TRUE)
            set(SOURCE_LANG CXX)
            set(COMPILER_LAUNCHER ${PRIMARY_CXX_LAUNCHER})
            set(COMPILER ${${CT_CXX_COMPILER}})
            set(OBJ_EXT ${CMAKE_CXX_OUTPUT_EXTENSION})
            set(LANGUAGE_STANDARD_ARG ${ARG_CXX_STANDARD})
        else()
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: "
                "unknown source file language - cannot proceed."
            )
        endif()

        if (NOT COMPILER)
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: "
                "missing compiler for handling ${SRC_EXT} files"
            )
        endif()

        set(OBJ_FILE ${OBJ_DIR}/${SRC_STEM}${OBJ_EXT})
        set(DEP_FILE ${OBJ_DIR}/${SRC_STEM}.d)

        file(MAKE_DIRECTORY ${OBJ_DIR})

        # Use the compile rule to generate a compiler invocation command
        set(COMPILER_INVOCATION ${ARG_COMPILE_RULE})

        list(
            TRANSFORM COMPILER_INVOCATION
            REPLACE
            "<COMPILER>" "${COMPILER_LAUNCHER};${COMPILER}"
        )
        list(TRANSFORM COMPILER_INVOCATION REPLACE "<OBJECT>" "${OBJ_FILE}")
        list(TRANSFORM COMPILER_INVOCATION REPLACE "<DEPFILE>" "${DEP_FILE}")
        list(
            TRANSFORM COMPILER_INVOCATION
            REPLACE
            "<DEFINES>" "${ARG_COMPILE_DEFINITIONS_ARGS}"
        )
        list(
            TRANSFORM COMPILER_INVOCATION
            REPLACE
            "<INCLUDES>" "${ARG_INCLUDE_FLAGS_ARGS}"
        )

        list(
            TRANSFORM COMPILER_INVOCATION
            REPLACE
            "<FLAGS>" "${LANGUAGE_STANDARD_ARG};${ARG_COMPILE_OPTIONS}"
        )
        list(TRANSFORM COMPILER_INVOCATION REPLACE "<INPUT>" "${SRC_FILE}")

        if (NOT SYSTEM_MAX_ARG_LENGTH)
            if (WIN32)
                set(MAX_ARG_LENGTH 8190)
            else()
                find_program(CT_GETCONF getconf)

                if (CT_GETCONF)
                    execute_process(
                        COMMAND ${CT_GETCONF} ARG_MAX
                        OUTPUT_VARIABLE MAX_ARG_LENGTH
                        OUTPUT_STRIP_TRAILING_WHITESPACE
                        COMMAND_ERROR_IS_FATAL ANY
                    )
                else()
                    # _POSIX_ARG_MAX
                    set(MAX_ARG_LENGTH 4096)
                endif()
            endif()

            set(
                SYSTEM_MAX_ARG_LENGTH ${MAX_ARG_LENGTH}
                CACHE
                STRING
                "The system's maximum command length"
            )
        endif()

        string(LENGTH COMPILER_INVOCATION COMMAND_LENGTH)

        # Use response file if max command-line length is exceeded
        if (ARG_USE_RSP_FILE OR COMMAND_LENGTH GREATER SYSTEM_MAX_ARG_LENGTH)
            set(RSP_FILE ${OBJ_DIR}/${SRC_STEM}.rsp)

            set(COMPILER_ARGS ${COMPILER_INVOCATION})

            if (COMPILER_LAUNCHER)
                list(POP_FRONT COMPILER_ARGS)
            endif()

            list(POP_FRONT COMPILER_ARGS)

            string(REPLACE ";" " " COMPILER_ARGS "${COMPILER_ARGS}")

            file(WRITE ${RSP_FILE} "${COMPILER_ARGS}")

            set(
                COMPILER_INVOCATION
                "${COMPILER_LAUNCHER}"
                "${COMPILER}"
                "${ARG_RESPONSE_FILE_FLAG}${RSP_FILE}"
            )
        endif()

        cmake_path(
            RELATIVE_PATH OBJ_FILE
            BASE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            OUTPUT_VARIABLE OBJ_FILE_RELATIVE
        )

        add_custom_command(
            OUTPUT ${OBJ_FILE} ${DEP_FILE}
            COMMAND ${COMPILER_INVOCATION}
            ${OPTION_JOB_POOL_COMPILE}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDS ${SRC_FILE}
            DEPFILE ${DEP_FILE}
            COMMAND_EXPAND_LISTS
            COMMENT "Building ${SOURCE_LANG} object ${OBJ_FILE_RELATIVE}"
            VERBATIM
        )

        list(APPEND OBJ_FILES ${OBJ_FILE})
        list(APPEND DEP_FILES ${DEP_FILE})
    endforeach()

    if (NOT DEFINED ARG_LINK_OPTIONS)
        _get_target_property_detail(
            ARG_LINK_OPTIONS
            ${ARG_PRIMARY}
            LINK_OPTIONS
        )
    endif()

    if (NOT DEFINED ARG_LINK_DIRECTORIES)
        _get_target_property_detail(
            ARG_LINK_DIRECTORIES
            ${ARG_PRIMARY}
            LINK_DIRECTORIES
        )

        list(TRANSFORM ARG_LINK_DIRECTORIES PREPEND "-L")
    endif()

    if (NOT DEFINED ARG_LINK_LIBRARIES)
        _get_target_property_detail(
            ARG_LINK_LIBRARIES
            ${ARG_PRIMARY}
            LINK_LIBRARIES
        )
    endif()

    unset(LINK_OBJECTS)
    unset(LINK_LIB_TARGETS)
    unset(LINK_ARGS_LIB_PATHS)
    unset(LINK_ARGS_LIBS)

    foreach (LIB ${ARG_LINK_LIBRARIES})
        if (TARGET ${LIB})
            list(APPEND LINK_LIB_TARGETS ${LIB})

            _get_target_property_detail(
                LIB_BINARY_DIR
                ${LIB}
                BINARY_DIR
            )

            _get_target_property_detail(
                LIB_TYPE
                ${LIB}
                CT_TARGET_TYPE
            )

            if (NOT LIB_TYPE)
                _get_target_property_detail(
                    LIB_TYPE
                    ${LIB}
                    TYPE
                )
            endif()

            if ("${LIB_TYPE}" STREQUAL "SHARED_LIBRARY")
                _get_target_property_detail(
                    LIB_RUNTIME_OUTPUT_DIRECTORY
                    ${LIB}
                    RUNTIME_OUTPUT_DIRECTORY
                )

                cmake_path(
                    APPEND LIB_BINARY_DIR
                           ${LIB_RUNTIME_OUTPUT_DIRECTORY}
                    OUTPUT_VARIABLE LIB_PATH
                )

                # Use '-rpath' to hint to the dynamic linker where shared
                # libraries will be found.
                list(APPEND LINK_ARGS_LIBS -l${LIB})
                list(APPEND LINK_ARGS_LIB_PATHS -L${LIB_PATH})
                list(APPEND ARG_LINK_OPTIONS "-Wl,-rpath,${LIB_PATH}")
            elseif ("${LIB_TYPE}" STREQUAL "OBJECT_LIBRARY")
                _get_target_property_detail(
                    LIB_OBJECTS
                    ${LIB}
                    CT_OBJECTS
                )

                # FIXME: what if no objects are retrieveable?
                # Looks like cmake prepends the objects of object libraries
                # to the target's objects for the linker invocation.
                # We implement the same behavior so that using the same
                # toolchain for the clone as for the primary will result in
                # the same binaries.
                list(APPEND LINK_OBJECTS ${LIB_OBJECTS})
            else()
                list(APPEND LINK_ARGS_LIBS -l${LIB})
                list(APPEND LINK_ARGS_LIB_PATHS -L${LIB_BINARY_DIR})
            endif()
        endif()
    endforeach()

    list(APPEND LINK_OBJECTS ${OBJ_FILES})

    _get_target_property_detail(
        PRIMARY_LINK_DEPENDS
        ${ARG_PRIMARY}
        LINK_DEPENDS
    )

    _get_target_property_detail(
        PRIMARY_JOB_POOL_LINK
        ${ARG_PRIMARY}
        JOB_POOL_LINK
    )

    if (PRIMARY_JOB_POOL_LINK)
        set(OPTION_JOB_POOL_LINK JOB_POOL ${PRIMARY_JOB_POOL_LINK})
    endif()


    _get_target_property_detail(
        PRIMARY_TYPE
        ${ARG_PRIMARY}
        TYPE
    )

    if ("${PRIMARY_TYPE}" STREQUAL "UTILITY")
        _get_target_property_detail(
            PRIMARY_TYPE
            ${ARG_PRIMARY}
            CUSTOM_TARGET_TYPE
        )
    endif()

    _get_target_property_detail(
        PRIMARY_RUNTIME_OUTPUT_DIRECTORY
        ${ARG_PRIMARY}
        RUNTIME_OUTPUT_DIRECTORY
    )

    # Target type-specific adaptions
    if ("${PRIMARY_TYPE}" STREQUAL "EXECUTABLE")
        set(BIN_NAME ${ARG_NAME}${CMAKE_EXECUTABLE_SUFFIX})
        set(AUX_BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})

        cmake_path(
            APPEND CMAKE_CURRENT_BINARY_DIR
                   ${PRIMARY_RUNTIME_OUTPUT_DIRECTORY}
                   ${BIN_NAME}
            OUTPUT_VARIABLE BIN_FILE
        )

        set(
            LINK_ARGS_OPTIONS
            ${ARG_LINK_OPTIONS}
            ${ARG_LINK_DIRECTORIES}
            ${LINK_ARGS_LIB_PATHS}
        )
    elseif ("${PRIMARY_TYPE}" STREQUAL "OBJECT_LIBRARY")
        # Object libraries are treated special.
        set(BIN_NAME ${ARG_NAME}.tag)
        set(AUX_BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})
        set(BIN_FILE ${CMAKE_CURRENT_BINARY_DIR}/${BIN_NAME})

        set(ARG_LINK_RULE "${CMAKE_COMMAND}" -E touch "${AUX_BIN_FILE}")
    elseif ("${PRIMARY_TYPE}" STREQUAL "STATIC_LIBRARY")
        set(BIN_NAME lib${ARG_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX})
        set(AUX_BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})
        set(BIN_FILE ${CMAKE_CURRENT_BINARY_DIR}/${BIN_NAME})

        set(LINK_ARGS_OPTIONS ${ARG_LINK_OPTIONS})
    elseif ("${PRIMARY_TYPE}" STREQUAL "SHARED_LIBRARY")
        set(BIN_NAME lib${ARG_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX})
        set(AUX_BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})

        cmake_path(
            APPEND CMAKE_CURRENT_BINARY_DIR
                   ${PRIMARY_RUNTIME_OUTPUT_DIRECTORY}
                   ${BIN_NAME}
            OUTPUT_VARIABLE BIN_FILE
        )

        set(
            LINK_ARGS_OPTIONS
            -fPIC
            -shared
            -Wl,-soname,${BIN_NAME}
            ${ARG_LINK_OPTIONS}
            ${ARG_LINK_DIRECTORIES}
            ${LINK_ARGS_LIB_PATHS}
        )
    else()
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "unsupported primary type \"${PRIMARY_TYPE}\""
        )
    endif()

    # Use the link rule to generate a linker invocation command
    set(LINKER_INVOCATION ${ARG_LINK_RULE})

    list(TRANSFORM LINKER_INVOCATION REPLACE "<LINKER>" "${${CT_LINKER}}")
    list(TRANSFORM LINKER_INVOCATION REPLACE "<OPTIONS>" "${LINK_ARGS_OPTIONS}")
    list(TRANSFORM LINKER_INVOCATION REPLACE "<OBJECTS>" "${LINK_OBJECTS}")
    list(TRANSFORM LINKER_INVOCATION REPLACE "<LIBRARIES>" "${LINK_ARGS_LIBS}")
    list(TRANSFORM LINKER_INVOCATION REPLACE "<OUTPUT>" "${AUX_BIN_FILE}")

    string(LENGTH LINKER_INVOCATION COMMAND_LENGTH)

    # Use response file if max command-line length is exceeded
    if (ARG_USE_RSP_FILE OR COMMAND_LENGTH GREATER SYSTEM_MAX_ARG_LENGTH)
        set(RSP_FILE ${OBJ_DIR}/${SRC_STEM}.rsp)
        cmake_path(
            REPLACE_EXTENSION
            AUX_BIN_FILE ".rsp"
            OUTPUT_VARIABLE RSP_FILE
        )

        set(LINKER_ARGS ${LINKER_INVOCATION})

        list(POP_FRONT LINKER_ARGS)

        string(REPLACE ";" " " LINKER_ARGS "${LINKER_ARGS}")

        file(WRITE ${RSP_FILE} "${LINKER_ARGS}")

        set(
            LINKER_INVOCATION
            "${${CT_LINKER}}"
            "${ARG_RESPONSE_FILE_FLAG}${RSP_FILE}"
        )
    endif()

    if (TARGET_USES_CXX)
        set(TARGET_LANG CXX)
    else()
        set(TARGET_LANG C)
    endif()

    #
    # The file 'copy' invocation is a trick to avoid a cmake error which
    # occurs when cmake detects a logical target name colliding with a
    # file name from one of the logical targets dependencies.
    #
    # Here is an example which would produce the error:
    #   add_custom_target(app DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/app)
    #
    add_custom_command(
        OUTPUT ${AUX_BIN_FILE}
        COMMAND ${LINKER_INVOCATION}
        COMMAND ${CMAKE_COMMAND} -E copy
                ${AUX_BIN_FILE}
                ${BIN_FILE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        ${OPTION_JOB_POOL_LINK}
        DEPENDS ${LINK_OBJECTS}
                ${LINK_LIB_TARGETS}
                ${PRIMARY_LINK_DEPENDS}
        COMMAND_EXPAND_LISTS
        COMMENT "Linking ${TARGET_LANG} executable ${BIN_NAME}"
        VERBATIM
    )

    add_custom_target(${ARG_NAME} DEPENDS ${AUX_BIN_FILE})

    if (ARG_EXCLUDE_FROM_ALL)
        set(EXCLUDE_FROM_ALL TRUE)
    else()
        set(EXCLUDE_FROM_ALL FALSE)
    endif()

    set_target_properties(
        ${ARG_NAME}
        PROPERTIES
        COMPILE_DEFINITIONS "${ARG_COMPILE_DEFINITIONS_ARGS}"
        COMPILE_OPTIONS "${ARG_COMPILE_OPTIONS}"
        CXX_COMPILER_LAUNCHER "${PRIMARY_CXX_LAUNCHER}"
        CXX_STANDARD "${ARG_CXX_STANDARD}"
        C_COMPILER_LAUNCHER "${PRIMARY_CC_LAUNCHER}"
        C_STANDARD "${ARG_C_STANDARD}"
        EXCLUDE_FROM_ALL "${EXCLUDE_FROM_ALL}"
        INCLUDE_DIRECTORIES "${ARG_INCLUDE_FLAGS_ARGS}"
        JOB_POOL_COMPILE "${PRIMARY_JOB_POOL_COMPILE}"
        JOB_POOL_LINK "${PRIMARY_JOB_POOL_LINK}"
        LINK_DEPENDS "${PRIMARY_LINK_DEPENDS}"
        LINK_LIBRARIES "${ARG_LINK_LIBRARIES}"
        LINK_OPTIONS "${ARG_LINK_OPTIONS}"
        OUTPUT_NAME "${BIN_NAME}"
        RUNTIME_OUTPUT_DIRECTORY "${PRIMARY_RUNTIME_OUTPUT_DIRECTORY}"
        SOURCES "${PRIMARY_SOURCES}"

        # Cloned target-specific properties
        CT_PRIMARY_NAME "${ARG_PRIMARY}"
        CT_TARGET_TYPE "${PRIMARY_TYPE}"
        CT_OBJECTS "${OBJ_FILES}"
        CT_DEPENDENCY_FILES "${DEP_FILES}"
    )

endfunction()

