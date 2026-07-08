#!/bin/bash

set -euo pipefail

output="libabsl-shared-${1}.tar.gz"
set --

if [[ $output == *linux* ]]; then
	yum -y install ninja-build
fi

cmake_configure_args_common=(
	-DCMAKE_BUILD_TYPE=Release
	-DCMAKE_INSTALL_PREFIX=./install
	-DCMAKE_CXX_STANDARD=17
	-DCMAKE_CXX_EXTENSIONS=OFF
	-DCMAKE_CXX_STANDARD_REQUIRED=ON
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
	-DBUILD_SHARED_LIBS=ON
	'-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64'
	-DCMAKE_VERBOSE_MAKEFILE=ON
	-DCMAKE_OSX_DEPLOYMENT_TARGET=10.13
	-DABSL_PROPAGATE_CXX_STD=ON
	-Sabseil-cpp
	-Bbuild
	-GNinja
)

cmake "${cmake_configure_args_common[@]}" \
	-DBUILD_TESTING=OFF -DABSL_BUILD_TESTING=OFF
cmake --build build -j --target all
cmake --install build
# pypa build environment installs at lib64
if [[ ! -d install/lib ]]; then
	ln -s lib64 install/lib
fi
tar -cvzf "${output}" -C install .

find build -name CMakeCache.txt -delete
cmake "${cmake_configure_args_common[@]}" \
	-DBUILD_TESTING=ON -DABSL_BUILD_TESTING=ON -DABSL_USE_GOOGLETEST_HEAD=ON
cmake --build build -j --target all
