#!/usr/bin/env bash
#
# Build Bullet3 and SoLoud static libraries for the current or a target platform.
#
# Usage:
#   ./build-libs-cross.sh                    # Native build for current OS/arch
#   ./build-libs-cross.sh riscv64            # Cross-compile for linux/riscv64
#   ./build-libs-cross.sh aarch64            # Cross-compile for linux/arm64
#
# Prerequisites:
#   - CMake
#   - Native: make (Linux/macOS) or mingw32-make (Windows/MinGW)
#   - Cross-compilation: <arch>-linux-gnu-gcc/g++ toolchain
#   - macOS: Xcode command line tools
#   - Windows: MinGW (MSYS2 recommended)
#
# Output: .a files are copied into this directory (src/libs/) with the naming
#         convention expected by the engine's CGo directives.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# --- Detect host environment ---

detect_os() {
	case "$(uname -s)" in
		Linux*)            echo "linux" ;;
		Darwin*)           echo "darwin" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*)
			echo "Unsupported OS: $(uname -s)" >&2
			exit 1
			;;
	esac
}

detect_arch() {
	case "$(uname -m)" in
		x86_64|amd64)   echo "x86_64" ;;
		aarch64|arm64)   echo "aarch64" ;;
		riscv64)         echo "riscv64" ;;
		*)               echo "$(uname -m)" ;;
	esac
}

# Portable CPU count
ncpu() {
	nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1
}

HOST_OS="$(detect_os)"
HOST_ARCH="$(detect_arch)"
TARGET_ARCH="${1:-$HOST_ARCH}"

# Determine if this is a cross-compilation and set up accordingly.
CROSS=false
DARWIN_CROSS=false
if [ "$TARGET_ARCH" != "$HOST_ARCH" ]; then
	if [ "$HOST_OS" = "linux" ]; then
		CROSS=true
		CC="${TARGET_ARCH}-linux-gnu-gcc"
		CXX="${TARGET_ARCH}-linux-gnu-g++"
	elif [ "$HOST_OS" = "darwin" ]; then
		# macOS clang supports cross-arch via -DCMAKE_OSX_ARCHITECTURES.
		# Map our target arch to the Apple architecture name.
		case "$TARGET_ARCH" in
			x86_64|amd64)    DARWIN_TARGET_ARCH="x86_64" ;;
			aarch64|arm64)   DARWIN_TARGET_ARCH="arm64" ;;
			*)
				echo "Unsupported macOS target architecture: $TARGET_ARCH" >&2
				exit 1
				;;
		esac
		DARWIN_CROSS=true
	else
		echo "Cross-compilation on ${HOST_OS} is not supported." >&2
		exit 1
	fi
fi

# Map toolchain arch name to Go arch name used in library suffixes.
case "$TARGET_ARCH" in
	riscv64)         GOARCH="riscv64" ;;
	aarch64|arm64)   GOARCH="arm64" ;;
	x86_64|amd64)    GOARCH="amd64" ;;
	*)               GOARCH="$TARGET_ARCH" ;;
esac

# --- Platform-specific cmake / build settings ---

case "$HOST_OS" in
	linux)
		PLATFORM="nix"
		CMAKE_GENERATOR="Unix Makefiles"
		MAKE_CMD="make"
		SOLOUD_BACKEND="-DSOLOUD_BACKEND_ALSA=ON"
		;;
	darwin)
		PLATFORM="darwin"
		CMAKE_GENERATOR="Unix Makefiles"
		MAKE_CMD="make"
		SOLOUD_BACKEND="-DSOLOUD_BACKEND_COREAUDIO=ON"
		;;
	windows)
		PLATFORM="win"
		CMAKE_GENERATOR="MinGW Makefiles"
		MAKE_CMD="mingw32-make"
		SOLOUD_BACKEND="-DSOLOUD_BACKEND_WASAPI=ON"
		;;
esac

# --- Library naming conventions (must match CGo directives) ---

# Bullet3: always <name>_<platform>_<goarch>.a
BULLET_SUFFIX="_${PLATFORM}_${GOARCH}"

# SoLoud has two legacy names that differ from the general pattern:
#   linux/amd64  -> libsoloud_nix.a       (no arch suffix)
#   windows      -> libsoloud_win32.a     (win32, not win_amd64)
case "${PLATFORM}_${GOARCH}" in
	nix_amd64) SOLOUD_NAME="libsoloud_nix" ;;
	win_amd64) SOLOUD_NAME="libsoloud_win32" ;;
	*)         SOLOUD_NAME="libsoloud_${PLATFORM}_${GOARCH}" ;;
esac

echo "=== Building for ${PLATFORM}/${GOARCH} ==="
if $CROSS; then
	echo "    Cross-compiling with: ${TARGET_ARCH}-linux-gnu-gcc/g++"
elif $DARWIN_CROSS; then
	echo "    Cross-compiling with: CMAKE_OSX_ARCHITECTURES=${DARWIN_TARGET_ARCH}"
fi
echo "    Bullet3 suffix: ${BULLET_SUFFIX}"
echo "    SoLoud name:    ${SOLOUD_NAME}"
echo "    Work dir:       ${WORK_DIR}"
echo ""

# --- Bullet3 ---

echo "--- Bullet3 ---"
cd "$WORK_DIR"
git clone --depth 1 https://github.com/bulletphysics/bullet3.git
cd bullet3
mkdir build && cd build

cmake_args=(
	-G "$CMAKE_GENERATOR"
	-DCMAKE_BUILD_TYPE=Release
	-DBUILD_SHARED_LIBS=OFF
	-DBUILD_CPU_DEMOS=OFF
	-DBUILD_OPENGL3_DEMOS=OFF
	-DBUILD_BULLET2_DEMOS=OFF
	-DBUILD_EXTRAS=OFF
	-DBUILD_UNIT_TESTS=OFF
	-DUSE_GLUT=OFF
	-DINSTALL_LIBS=ON
)
if $CROSS; then
	cmake_args+=(
		-DCMAKE_SYSTEM_NAME=Linux
		-DCMAKE_SYSTEM_PROCESSOR="$TARGET_ARCH"
		-DCMAKE_C_COMPILER="$CC"
		-DCMAKE_CXX_COMPILER="$CXX"
	)
elif $DARWIN_CROSS; then
	cmake_args+=(-DCMAKE_OSX_ARCHITECTURES="$DARWIN_TARGET_ARCH")
fi

cmake .. "${cmake_args[@]}"
$MAKE_CMD -j"$(ncpu)"

for lib in \
	src/BulletDynamics/libBulletDynamics.a \
	src/BulletCollision/libBulletCollision.a \
	src/LinearMath/libLinearMath.a \
	src/BulletSoftBody/libBulletSoftBody.a \
	src/BulletInverseDynamics/libBulletInverseDynamics.a \
	src/Bullet3Dynamics/libBullet3Dynamics.a \
	src/Bullet3Collision/libBullet3Collision.a \
	src/Bullet3Common/libBullet3Common.a \
	src/Bullet3Geometry/libBullet3Geometry.a \
	src/Bullet3OpenCL/libBullet3OpenCL_clew.a \
	src/Bullet3Serialize/Bullet2FileLoader/libBullet2FileLoader.a \
	; do
	if [ -f "$lib" ]; then
		base="$(basename "$lib" .a)"
		dest="${SCRIPT_DIR}/${base}${BULLET_SUFFIX}.a"
		cp "$lib" "$dest"
		echo "  -> $(basename "$dest")"
	fi
done

# --- SoLoud ---

echo ""
echo "--- SoLoud ---"
cd "$WORK_DIR"
git clone --depth 1 https://github.com/jarikomppa/soloud.git
cd soloud/contrib
mkdir build && cd build

cmake_args=(
	-G "$CMAKE_GENERATOR"
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5
	-DSOLOUD_BACKEND_SDL2=OFF
	"$SOLOUD_BACKEND"
	-DSOLOUD_C_API=ON
	-DSOLOUD_STATIC=ON
)
if $CROSS; then
	cmake_args+=(
		-DCMAKE_SYSTEM_NAME=Linux
		-DCMAKE_SYSTEM_PROCESSOR="$TARGET_ARCH"
		-DCMAKE_C_COMPILER="$CC"
		-DCMAKE_CXX_COMPILER="$CXX"
		"-DCMAKE_C_FLAGS=-I/usr/include"
		"-DCMAKE_CXX_FLAGS=-I/usr/include"
	)
elif $DARWIN_CROSS; then
	cmake_args+=(-DCMAKE_OSX_ARCHITECTURES="$DARWIN_TARGET_ARCH")
fi

cmake .. "${cmake_args[@]}"
cmake --build . --config Release

SOLOUD_LIB="$(find . -name 'libsoloud*.a' -print -quit)"
if [ -n "$SOLOUD_LIB" ]; then
	cp "$SOLOUD_LIB" "${SCRIPT_DIR}/${SOLOUD_NAME}.a"
	echo "  -> ${SOLOUD_NAME}.a"
fi

echo ""
echo "=== Done. Libraries installed to ${SCRIPT_DIR} ==="
