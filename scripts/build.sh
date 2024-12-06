#!/bin/bash

set -euo pipefail

output="libabsl-static-${1}.tar.gz"
set --

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./install \
	-DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_EXTENSIONS=OFF \
	-DCMAKE_CXX_STANDARD_REQUIRED=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	'-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64' -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
	-DBUILD_TESTING=ON -DABSL_BUILD_TESTING=ON -DABSL_USE_GOOGLETEST_HEAD=ON \
	-S abseil-cpp -B build -G Ninja

cmake --build build -j --target all

if [[ $output == *-macosx_* ]]; then
	arch -arm64 ctest --test-dir build -T test --output-on-failure -j
	arch -x86_64 ctest --test-dir build -T test --output-on-failure -j
else
	ctest --test-dir build -T test --output-on-failure -j
fi

cmake --install build
tar -cvzf "${output}" -C install .
