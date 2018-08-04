#!/bin/bash

set -ex

pip install --user --no-cache-dir hypothesis==3.59.0

# The INSTALL_PREFIX here must match up with test.sh
INSTALL_PREFIX="/usr/local/caffe2"
LOCAL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$LOCAL_DIR"/../.. && pwd)
CMAKE_ARGS=()

##############################################################################
# Explicitly set Python executable.
###############################################################################
# On Ubuntu 16.04 the default Python is still 2.7.
PYTHON="$(which python)"

###############################################################################
# Set cmake args
###############################################################################
CMAKE_ARGS+=("-DBUILD_BINARY=ON")
CMAKE_ARGS+=("-DBUILD_TEST=ON")
CMAKE_ARGS+=("-DINSTALL_TEST=ON")
CMAKE_ARGS+=("-DUSE_OBSERVERS=ON")
CMAKE_ARGS+=("-DUSE_ZSTD=ON")
CMAKE_ARGS+=("-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}")

# TODO: This is patching the official FindHip to properly handly
# cmake generator expression. A PR is opened in the upstream repo here:
# https://github.com/ROCm-Developer-Tools/HIP/pull/516
# remove this hack once it's merged.
if [[ -f /opt/rocm/hip/cmake/FindHIP.cmake ]]; then
  sudo sed -i 's/\ -I${dir}/\ $<$<BOOL:${dir}>:-I${dir}>/' /opt/rocm/hip/cmake/FindHIP.cmake
fi

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export HCC_AMDGPU_TARGET=gfx900

########## HIPIFY Caffe2 operators
${PYTHON} "${ROOT_DIR}/tools/amd_build/build_caffe2_amd.py"

# Try to include Redis support for Linux builds
if [ "$(uname)" == "Linux" ]; then
  CMAKE_ARGS+=("-DUSE_REDIS=ON")
fi

# We test the presence of cmake3 (for platforms like Centos and Ubuntu 14.04)
# and use that if so.
if [[ -x "$(command -v cmake3)" ]]; then
    CMAKE_BINARY=cmake3
else
    CMAKE_BINARY=cmake
fi

MAX_JOBS=$(nproc)




###############################################################################
# Configure and make
###############################################################################
# Run cmake from ./build_caffe2 directory so it doesn't conflict with
# standard PyTorch build directory. Eventually these won't need to
# be separate.
rm -rf build_caffe2
mkdir build_caffe2
cd ./build_caffe2

# Configure
${CMAKE_BINARY} "${ROOT_DIR}" ${CMAKE_ARGS[*]} "$@"

# Build
if [ "$(uname)" == "Linux" ]; then
  make "-j${MAX_JOBS}" install
else
  echo "Don't know how to build on $(uname)"
  exit 1
fi

###############################################################################
# Install ONNX
###############################################################################

# Install ONNX into a local directory
pip install --user -b /tmp/pip_install_onnx "file://${ROOT_DIR}/third_party/onnx#egg=onnx"

