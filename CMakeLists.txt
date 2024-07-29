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

cmake_minimum_required(VERSION 3.28)

set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_C_FLAGS_DEBUG "")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "")
set(CMAKE_C_FLAGS_MINSIZEREL "")
set(CMAKE_C_FLAGS_RELEASE "")

set(CMAKE_CXX_FLAGS_DEBUG "")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "")
set(CMAKE_CXX_FLAGS_MINSIZEREL "")
set(CMAKE_CXX_FLAGS_RELEASE "")

include(cmake/clone-target.cmake)

project(clone-target LANGUAGES C CXX)

add_executable(
    hello-world
    src/hello-world.c
)

clone_target(
    hello-world-clone
    PRIMARY hello-world
    CC clang
    CXX clang++
    LD clang
    ${CLONE_TARGET_FLAGS}
    EXCLUDE_FROM_ALL
)

add_executable(
    goodbye-world
    src/goodbye-world.cpp
)

set_property(
    TARGET goodbye-world
    PROPERTY
    CXX_STANDARD 17
)

clone_target(
    goodbye-world-clone
    PRIMARY goodbye-world
    CXX clang++
    LD clang++
    ${CLONE_TARGET_FLAGS}
)

add_library(
    static-lib
    STATIC
    src/static-lib.c
)

set_property(
    TARGET static-lib
    PROPERTY
    C_STANDARD 11
)

target_include_directories(
    static-lib
    PRIVATE
    include
)

clone_target(
    static-lib-clone
    PRIMARY static-lib
    CC clang
    LD ar
    LINK_OPTIONS qc
    LINK_RULE <LINKER> <OPTIONS> <OUTPUT> <OBJECTS> <LIBRARIES>
    ${CLONE_TARGET_FLAGS}
)

add_executable(
    static-world
    src/static-world.c
)

target_include_directories(
    static-world
    PRIVATE
    include
)

target_link_libraries(
    static-world
    PRIVATE
    static-lib
)

clone_target(
    static-world-clone
    PRIMARY static-world
    CC clang
    LD clang
    LINK_LIBRARIES static-lib-clone
    ${CLONE_TARGET_FLAGS}
)

add_library(
    shared-lib
    SHARED
    src/shared-lib.cpp
)

set_property(
    TARGET shared-lib
    PROPERTY
    CXX_STANDARD 17
)

target_include_directories(
    shared-lib
    PRIVATE
    include
)

add_executable(
    shared-world
    src/shared-world.c
)

target_include_directories(
    shared-world
    PRIVATE
    include
)

target_link_libraries(
    shared-world
    PRIVATE
    static-lib
    shared-lib
)

clone_target(
    shared-lib-clone
    PRIMARY shared-lib
    CC clang
    CXX clang++
    LD clang++
    ${CLONE_TARGET_FLAGS}
)

clone_target(
    shared-world-clone
    PRIMARY shared-world
    CC clang
    CXX clang++
    LD clang++
    LINK_LIBRARIES static-lib-clone
                   shared-lib-clone
    ${CLONE_TARGET_FLAGS}
)

add_library(
    object-lib
    OBJECT
    src/static-lib.c
    src/shared-lib.cpp
)

target_include_directories(
    object-lib
    PRIVATE
    include
)

add_executable(
    object-world
    src/shared-world.c
)

target_include_directories(
    object-world
    PRIVATE
    include
)

target_link_libraries(
    object-world
    PRIVATE
    object-lib
)

clone_target(
    object-lib-clone
    PRIMARY object-lib
    CC clang
    CXX clang++
    LD clang++
    ${CLONE_TARGET_FLAGS}
)

clone_target(
    object-world-clone
    PRIMARY object-world
    CC clang
    CXX clang++
    LD clang++
    LINK_LIBRARIES object-lib-clone
    ${CLONE_TARGET_FLAGS}
)

get_target_property(OUTPUT_DIRECTORY object-world-clone RUNTIME_OUTPUT_DIRECTORY)
get_target_property(OUTPUT_FILE object-world-clone OUTPUT_NAME)

cmake_path(APPEND OUTPUT_DIRECTORY ${OUTPUT_FILE} OUTPUT_VARIABLE TARGET_FILE)

add_custom_target(
    run-object-world-clone
    ALL
    COMMAND ./${TARGET_FILE}
    DEPENDS object-world-clone
)

