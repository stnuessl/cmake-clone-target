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
        PRIMARY
        RESPONSE_FILE_FLAG
        OUTPUT_DIRECTORY
        OUTPUT_DEPS
        OUTPUT_OBJS
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

    if (NOT DEFINED ARG_CC)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "variable CC not set - C compiler must be specified"
        )
    endif()

    if (NOT DEFINED ARG_CXX)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "variable CXX not set - C++ compiler must be specified"
        )
    endif()

    if (NOT DEFINED ARG_LD)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "variable LD not set - linker must be specified"
        )
    endif()

    find_program(ARG_CC ${ARG_CC} REQUIRED)
    find_program(ARG_CXX ${ARG_CXX} REQUIRED)
    find_program(ARG_LD ${ARG_LD} REQUIRED)

    if (NOT DEFINED ARG_RESPONSE_FILE_FLAG)
        set(ARG_RESPONSE_FILE_FLAG "@")
    endif()

    if (NOT DEFINED ARG_OUTPUT_DIRECTORY)
        set(ARG_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    set(OUTPUT_DIRECTORY ${ARG_OUTPUT_DIRECTORY}/${ARG_NAME})

    if (NOT DEFINED ARG_COMPILE_RULE)
        set(
            ARG_COMPILE_RULE 
            <COMPILER>
            -MD 
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

    unset(OBJ_FILES)
    unset(DEP_FILES)

    foreach(SRC_FILE ${PRIMARY_SOURCES})
        cmake_path(
            ABSOLUTE_PATH SRC_FILE
            BASE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            NORMALIZE
        )

        cmake_path(HASH SRC_FILE SRC_HASH)

        set(OBJ_DIR ${OUTPUT_DIRECTORY}/${SRC_HASH})

        cmake_path(GET SRC_FILE STEM SRC_STEM)
        cmake_path(GET SRC_FILE EXTENSION SRC_EXT)

        string(TOLOWER ${SRC_EXT} SRC_EXT)

        if ("${SRC_EXT}" STREQUAL ".c")
            set(COMPILER ${ARG_CC})
            set(OBJ_EXT ${CMAKE_C_OUTPUT_EXTENSION})
            set(LANGUAGE_STANDARD_ARG ${ARG_C_STANDARD})
        elseif ("${SRC_EXT}" MATCHES "\.c(c|pp|xx)")
            set(COMPILER ${ARG_CXX})
            set(OBJ_EXT ${CMAKE_CXX_OUTPUT_EXTENSION})
            set(LANGUAGE_STANDARD_ARG ${ARG_CXX_STANDARD})
        else()
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: "
                "unknown source file language - cannot proceed."
            )
        endif()

        set(OBJ_FILE ${OBJ_DIR}/${SRC_STEM}${OBJ_EXT})
        set(DEP_FILE ${OBJ_DIR}/${SRC_STEM}.d)

        file(MAKE_DIRECTORY ${OBJ_DIR})

        set(COMPILER_ARGS ${ARG_COMPILE_RULE})
        
        list(
            TRANSFORM COMPILER_ARGS 
            REPLACE 
            "<COMPILER>" "${COMPILER_LAUNCHER};${COMPILER}"
        )
        list(TRANSFORM COMPILER_ARGS REPLACE "<OBJECT>" "${OBJ_FILE}")
        list(TRANSFORM COMPILER_ARGS REPLACE "<DEPFILE>" "${DEP_FILE}")
        list(
            TRANSFORM COMPILER_ARGS 
            REPLACE 
            "<DEFINES>" "${ARG_COMPILE_DEFINITIONS_ARGS}"
        )
        list(
            TRANSFORM COMPILER_ARGS 
            REPLACE 
            "<INCLUDES>" "${ARG_INCLUDE_FLAGS_ARGS}"
        )

        list(
            TRANSFORM COMPILER_ARGS 
            REPLACE 
            "<FLAGS>" "${LANGUAGE_STANDARD_ARG};${ARG_COMPILE_OPTIONS}"
        )
        list(TRANSFORM COMPILER_ARGS REPLACE "<INPUT>" "${SRC_FILE}")

        set(
            COMPILER_INVOCATION 
            ${COMPILER_ARGS}
        )

        if (NOT SYSTEM_MAX_ARG_LENGTH)
            if (WIN32)
                set(MAX_ARG_LENGTH 8190)
            else()
                find_program(GETCONF getconf)
                
                if (GETCONF)
                    execute_process(
                        COMMAND ${GETCONF} ARG_MAX
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

        # Use response file if  Max command-line length is exceeded
        if (ARG_USE_RSP_FILE OR COMMAND_LENGTH GREATER SYSTEM_MAX_ARG_LENGTH)
            set(RSP_FILE ${OBJ_DIR}/${SRC_STEM}.rsp)

            string(REPLACE ";" " " COMPILER_ARGS "${COMPILER_ARGS}")

            file(WRITE ${RSP_FILE} "${COMPILER_ARGS}")

            set(
                COMPILER_INCOVATION
                ${COMPILER_LAUNCHER}
                ${COMPILER}
                ${ARG_RESPONSE_FILE_FLAG}${RSP_FILE}
            )
        endif()

        add_custom_command(
            OUTPUT ${OBJ_FILE} ${DEP_FILE}
            COMMAND ${COMPILER_INVOCATION}
            JOB_POOL ${PRIMARY_JOB_POOL_COMPILE} 
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDS ${SRC_FILE}
            DEPFILE ${DEP_FILE}
            COMMAND_EXPAND_LISTS
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

    unset(LINK_LIB_TARGETS)
    unset(LINK_LIB_PATHS)

    foreach (LIB ${ARG_LINK_LIBRARIES})
        if (TARGET ${LIB})
            list(APPEND LINK_LIB_TARGETS ${LIB})
            
            _get_target_property_detail(
                LIB_PATH
                ${LIB}
                RUNTIME_OUTPUT_DIRECTORY
            )

            list(APPEND LINK_LIB_PATHS -L${LIB_PATH})

            _get_target_property_detail(
                LIB_NAME
                ${LIB}
                OUTPUT_NAME
            )

            # Use '-rpath' to hint to the dynamic linker where shared libraries
            # will be found.
            # FIXME: Something like the property "TYPE" should be used instead,
            #        but it is read only.
            # FIXME: shared library file extension should be specifiable
            if ("${LIB_NAME}" MATCHES ".*\.so")
                list(APPEND ARG_LINK_OPTIONS "-Wl,-rpath,${LIB_PATH}")
            endif()
        endif()
    endforeach()

    list(TRANSFORM ARG_LINK_LIBRARIES PREPEND "-l")

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


    _get_target_property_detail(
        PRIMARY_TYPE
        ${ARG_PRIMARY}
        TYPE
    )

    # FIXME: ARG_LINK_RULE handling
    if ("${PRIMARY_TYPE}" STREQUAL "EXECUTABLE")
        set(BIN_NAME ${ARG_NAME})
        set(BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})
        set(
            LINKER_INVOCATION
            ${ARG_LD}
            ${ARG_LINK_OPTIONS}
            ${ARG_LINK_DIRECTORIES}
            ${LINK_LIB_PATHS}
            ${OBJ_FILES}
            ${ARG_LINK_LIBRARIES}
            -o ${BIN_FILE}
        )

    elseif ("${PRIMARY_TYPE}" STREQUAL "OBJECT_LIBRARY")
    elseif ("${PRIMARY_TYPE}" STREQUAL "STATIC_LIBRARY")
        set(BIN_NAME lib${ARG_NAME}.a)
        set(BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})

        set(
            LINKER_INVOCATION
            ${ARG_LD}
            ${ARG_LINK_OPTIONS}
            ${BIN_FILE}
            ${OBJ_FILES}
        )
    elseif ("${PRIMARY_TYPE}" STREQUAL "SHARED_LIBRARY")
        set(BIN_NAME lib${ARG_NAME}.so)
        set(BIN_FILE ${OUTPUT_DIRECTORY}/${BIN_NAME})

        set(
            LINKER_INVOCATION
            ${ARG_LD}
            -fPIC
            -shared
            -Wl,-soname,${BIN_NAME}
            ${ARG_LINK_OPTIONS}
            ${ARG_LINK_DIRECTORIES}
            ${LINK_LIB_PATHS}
            ${OBJ_FILES}
            ${ARG_LINK_LIBRARIES}
            -o ${BIN_FILE}
        )
    else()
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: "
            "unsupported primary type \"${PRIMARY_TYPE}\""
        )
    endif()
        

    add_custom_command(
        OUTPUT ${BIN_FILE}
        COMMAND ${LINKER_INVOCATION}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        JOB_POOL ${PRIMARY_JOB_POOL_LINK} 
        DEPENDS ${OBJ_FILES} 
                ${PRIMARY_LINK_DEPENDS} 
                ${LINK_LIB_TARGETS}
        COMMAND_EXPAND_LISTS
        VERBATIM
    )

    if (NOT ARG_EXCLUDE_FROM_ALL)
        set(TARGET_ALL_FLAG ALL)
    endif()

    add_custom_target(${ARG_NAME} ${TARGET_ALL_FLAG} DEPENDS ${BIN_FILE})

    # Define custom properties for cloned targets
    if (NOT CLONE_TARGET_PROPERTIES_DEFINED)
        define_property(TARGET PROPERTY OBJECTS)
        define_property(TARGET PROPERTY DEPENDENCY_FILES)

        set(
            CLONE_TARGET_PROPERTIES_DEFINED 1
            CACHE 
            INTERNAL 
            "Additional properties for cloned targets defined"
        )
    endif()

    set_target_properties(
        ${ARG_NAME}
        PROPERTIES
        COMPILE_DEFINITIONS "${ARG_COMPILE_DEFINITIONS_ARGS}"
        COMPILE_OPTIONS "${ARG_COMPILE_OPTIONS}"
        CXX_STANDARD "${ARG_CXX_STANDARD}"
        C_STANDARD "${ARG_C_STANDARD}"
        INCLUDE_DIRECTORIES "${ARG_INCLUDE_FLAGS_ARGS}"
        LINK_DEPENDS "${PRIMARY_LINK_DEPENDS}"
        LINK_LIBRARIES "${ARG_LINK_LIBRARIES}"
        LINK_OPTIONS "${ARG_LINK_OPTIONS}"
        OUTPUT_NAME "${BIN_NAME}"
        RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}"
        SOURCES "${PRIMARY_SOURCES}"
        JOB_POOL_LINK "${PRIMARY_JOB_POOL_LINK}"
        JOB_POOL_COMPILE "${PRIMARY_JOB_POOL_COMPILE}"
        EXCLUDE_FROM_ALL "${ARG_EXCLUDE_FROM_ALL}"
        OBJECTS "${OBJ_FILES}"
        DEPENDENCY_FILES "${DEP_FILES}"
    )

endfunction()



