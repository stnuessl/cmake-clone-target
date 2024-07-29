=====================================
clone_target - cmake utility function
=====================================

Work in Progress; project is still in prototype phase.

.. contents::
    :backlinks: top
    :depth: 2


Motivation
==========

Multiple toolchains required to deal with embedded software, unit tests
and static code analysis. Quite often these projects are also sacrificing
proper language server support often requiring a clang compilation database.
CMake has a limitation of only one toolchain file.
Projects usually implement quite hacky approaches to resolve the one toolchain
problem in cmake leading to difficult to understand and extend
The cmake function **clone_target** within this repository is one more
approach to resolve the one toolchain file issue while trying to keep
as much hard to understand cmake code abstracted away from the developers.

Example
=======

.. code-block::

    project(
        MyProject
        LANGUAGE C CXX
    )

    if (NOT EXISTS ${CMAKE_BINARY_DIR}/clone-target.cmake)
       file(
            DOWNLOAD <repository-url>
            ${CMAKE_BINARY_DIR}/clone-target.cmake
            TIMEOUT 5
       )
    endif()

    include(${CMAKE_BINARY_DIR}/clone-target.cmake)

    set(SOURCES "")
    set(INCLUDE_PATHS "")

    add_executable(
         Hidden-Executable
         EXCLUDE_FROM_ALL
         ${SOURCES}
    )

    target_include_directories(
        Hidden-Executable
        PRIVATE
        ${INCLUDE_PATHS}
    )

    clone_target(
         Executable
         PRIMARY Hidden-Executable
         CC ${EMBEDDED_C_COMPILER}
         CXX ${EMBEDDED_CXX_COMPILER}
         LD ${EMBEDDED_CXX_COMPILER}
    )

Features
========

* Works on executables, shared, static and object libraries.
* Use of response files for tool invocations exceeding the systems maximum
  command-line length.
* Use of compiler launchers like `ccache <https://ccache.dev/>`_.

Limitations
===========

The **clone_target** function is only supposed to be used in conjunction
with C and/or C++ targets.

Documentation
=============


Arguments
---------

PRIMARY
CC
CXX
LD
LINK_LIBRARIES
