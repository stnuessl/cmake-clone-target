#! /usr/bin/env bash
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

set -e

SOURCE_DIR="$(git rev-parse --show-toplevel)"
BINARY_DIR="${SOURCE_DIR}/build"

mkdir -p "${BINARY_DIR}"

cmake -GNinja -S "${SOURCE_DIR}" -B "${BINARY_DIR}"
cmake --build "${BINARY_DIR}"
rm -rf "${BINARY_DIR}"/*

cmake \
    -GNinja \
    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=bin \
    -S "${SOURCE_DIR}" \
    -B "${BINARY_DIR}"
cmake --build "${BINARY_DIR}"
rm -rf "${BINARY_DIR}"/*

cmake \
    -GNinja \
    -S "${SOURCE_DIR}" \
    -B "${BINARY_DIR}" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++

cmake --build "${BINARY_DIR}"

FILES=(
    "${BINARY_DIR}/hello-world"
    "${BINARY_DIR}/hello-world-clone/hello-world-clone"
    "${BINARY_DIR}/goodbye-world"
    "${BINARY_DIR}/goodbye-world-clone/goodbye-world-clone"
    "${BINARY_DIR}/object-world"
    "${BINARY_DIR}/object-world-clone/object-world-clone"
    "${BINARY_DIR}/static-world"
    "${BINARY_DIR}/static-world-clone/static-world-clone"
    # Seems like the cloned shared library cannot be exactly the same
    # as the primary one. Maybe this is due to internal file paths and similiar
    # things.
)

N="$(sha256sum "${FILES[@]}" | awk '{ print $1 }' | sort -u | wc -l)"

test ${N} -eq 4 || echo "test failed" && exit 1

#rm -rf "${BINARY_DIR}"/*
#
#cmake -GNinja \
#    -S "${SOURCE_DIR}" \
#    -B "${BINARY_DIR}" \
#    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
#
#cmake --build "${BINARY_DIR}"
