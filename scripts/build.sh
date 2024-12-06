#!/bin/bash

set -euo pipefail

output="libabsl-static-${1}.tar.gz"
set --

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./install \
	-DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_EXTENSIONS=OFF \
	-DCMAKE_CXX_STANDARD_REQUIRED=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
	-DBUILD_TESTING=ON -DABSL_BUILD_TESTING=ON -DABSL_USE_GOOGLETEST_HEAD=ON \
	-S abseil-cpp -B build -G Ninja

cmake --build build -j --target all
ctest -T build --output-on-failure -j
cmake --install build

tar -cvzf "${output}" -C install .
