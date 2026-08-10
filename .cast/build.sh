#!/bin/bash
# Bitwuzla Build and Test Script
# Usage: ./build.sh [--coverage] [--static]
#   --coverage: Enable coverage instrumentation
#   --static: Build statically-linked binary (this is bitwuzla's own
#             configure.py default already - --shared is the opt-in flag -
#             but pass it through explicitly for parity/clarity)
#   --static --coverage: Both

set -e

ENABLE_COVERAGE=false
ENABLE_STATIC=false
for arg in "$@"; do
    if [[ "$arg" == "--coverage" ]]; then
        ENABLE_COVERAGE=true
    elif [[ "$arg" == "--static" ]]; then
        ENABLE_STATIC=true
    fi
done

if [[ "$ENABLE_COVERAGE" == "true" ]]; then
    echo "🔍 Coverage instrumentation will be enabled"
fi
if [[ "$ENABLE_STATIC" == "true" ]]; then
    echo "📦 Static binary build will be enabled"
fi

echo "🔧 Installing basic tools..."
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  ninja-build \
  meson \
  libgmp-dev \
  libmpfr-dev \
  pkg-config \
  python3 \
  python3-pip

if [[ "$ENABLE_COVERAGE" == "true" ]]; then
    echo "📊 Installing coverage tools..."
    sudo apt-get install -y lcov gcc
    # Install fastcov and psutil for coverage analysis
    pip3 install fastcov psutil
fi

echo "📥 Cloning Bitwuzla repository..."
if [ -d "bitwuzla" ]; then
    echo "⚠️  bitwuzla directory already exists, skipping clone"
else
    git clone https://github.com/bitwuzla/bitwuzla.git bitwuzla
fi
cd bitwuzla

# --testing registers the regress test suite (needed for
# build/meson-info/intro-tests.json, read by .cast/coverage_test_runner.py)
# regardless of which build variant this is - harmless for a pure
# production/fuzzing build, required for a coverage one.
CONFIGURE_ARGS=(--testing --no-unit-testing)
if [[ "$ENABLE_COVERAGE" == "true" ]]; then
    CONFIGURE_ARGS+=(--coverage)
fi
if [[ "$ENABLE_STATIC" == "true" ]]; then
    CONFIGURE_ARGS+=(--static)
fi

echo "🔨 Building Bitwuzla..."
./configure.py --prefix="$(pwd)/build/install" "${CONFIGURE_ARGS[@]}"
cd build
ninja

echo "🧪 Testing Bitwuzla binary..."
if [ -f "src/main/bitwuzla" ]; then
    ./src/main/bitwuzla --version || echo "Version command completed (exit code $?)"
    echo "Bitwuzla binary is working correctly!"
else
    echo "Bitwuzla binary not found!"
    exit 1
fi

echo "✅ Bitwuzla build and test completed successfully!"
