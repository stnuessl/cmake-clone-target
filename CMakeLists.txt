

cmake_minimum_required(VERSION 3.28)

project(cmake-custom LANGUAGES C CXX)



include(cmake/clone-target.cmake)


add_executable(
    hello-world
    src/hello-world.c
)

clone_target(
    hello-world-clone
    PRIMARY hello-world
    CC clang 
    CXX clang++
    LD clang++
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
    CC clang 
    CXX clang++
    LD clang++
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
    CXX clang++
    LD ar
    LINK_OPTIONS qc
    LINK_RULE <OPTIONS> <OUTPUT> <OBJECTS> <LIBRARIES>
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
    CXX clang++
    LD clang++
    LINK_LIBRARIES static-lib-clone
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
)

clone_target(
    shared-world-clone
    PRIMARY shared-world
    CC clang
    CXX clang++
    LD clang++
    LINK_LIBRARIES static-lib-clone
                   shared-lib-clone
)
