#!/usr/bin/env bash
# Round 24 (native, stretch b): the library cross-compiled for Android arm64-v8a. `make native-android` (mk/native.mk)
# fetches the pinned NDK into .tools/ once per machine, builds godot-cpp for arm64 with the proof's numeric flags beside
# the desktop binding, then native/src into native/bin-android/libtank_native.android.arm64.so. Nothing here touches the
# desktop library or its .gdextension: an Android export's entry is a later step (`_agents/native.md` *Android*).
set -euo pipefail

: "${TOOLS_DIR:?}" "${DOWNLOADS:?}" "${NDK_VERSION:?}" "${NDK_SHA256:?}" "${NDK_URL:?}" "${GODOTCPP_SRC:?}"
: "${GODOTCPP_API:?the extension API the desktop build dumped}" "${NATIVE_FP_FLAGS:?}" "${NATIVE_DIR:?}"
: "${GODOTCPP_VERSION:?}" "${ANDROID_API:=24}" "${NATIVE_JOBS:=4}" "${NATIVE_CPUS:=}" "${CMAKE:=cmake}"

say() { echo ">> native-android: $*"; }
run() { if [ -n "$NATIVE_CPUS" ]; then taskset -c "$NATIVE_CPUS" "$@"; else "$@"; fi; }
abs() { python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1"; }

ndk="$TOOLS_DIR/android-ndk-$NDK_VERSION"
mkdir -p "$TOOLS_DIR" "$DOWNLOADS"
exec 9>"$TOOLS_DIR/.android-ndk.lock"
flock -w 3600 9 || { say "could not take the NDK lock"; exit 1; }
if [ ! -e "$ndk/.installed" ]; then
	zip="$DOWNLOADS/android-ndk-$NDK_VERSION-linux.zip"
	[ -s "$zip" ] || { say "downloading the NDK $NDK_VERSION (~660 MB)"; curl -fsSL --retry 3 -o "$zip" "$NDK_URL"; }
	echo "$NDK_SHA256  $zip" | sha256sum -c - >/dev/null || { say "the NDK zip's sha256 is not the pinned one"; exit 1; }
	rm -rf "$ndk"
	unzip -q "$zip" -d "$TOOLS_DIR"
	[ -d "$ndk" ] || { say "the zip did not unpack to $ndk"; exit 1; }
	touch "$ndk/.installed"
fi
flock -u 9
toolchain="$(abs "$ndk")/build/cmake/android.toolchain.cmake"
android_flags=(-DCMAKE_TOOLCHAIN_FILE="$toolchain" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$ANDROID_API"
	-DANDROID_STL=c++_static)

src_abs=$(abs "$GODOTCPP_SRC")
key=$(printf '%s' "$NATIVE_FP_FLAGS $NDK_VERSION $ANDROID_API" | sha256sum | cut -c1-8)
cpp_build="$src_abs/build-android-arm64-$key"
cpp_lib="$cpp_build/bin/libgodot-cpp.android.template_debug.arm64.a"
exec 8>"$TOOLS_DIR/.godot-cpp.lock"
flock -w 3600 8 || { say "could not take the godot-cpp lock"; exit 1; }
if [ ! -s "$cpp_lib" ]; then
	say "building godot-cpp $GODOTCPP_VERSION for arm64 ($NATIVE_FP_FLAGS)"
	start=$(date +%s)
	run "$CMAKE" -S "$src_abs" -B "$cpp_build" "${android_flags[@]}" -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_CXX_FLAGS_RELEASE="-DNDEBUG" -DCMAKE_CXX_FLAGS="$NATIVE_FP_FLAGS" -DGODOTCPP_TARGET=template_debug \
		-DGODOTCPP_PRECISION=single -DGODOTCPP_CUSTOM_API_FILE="$(abs "$GODOTCPP_API")" > "$cpp_build.configure.log" 2>&1 \
		|| { tail -30 "$cpp_build.configure.log"; say "godot-cpp configure FAILED"; exit 1; }
	run "$CMAKE" --build "$cpp_build" -j"$NATIVE_JOBS" > "$cpp_build.build.log" 2>&1 \
		|| { tail -30 "$cpp_build.build.log"; say "godot-cpp build FAILED"; exit 1; }
	found=$(find "$cpp_build/bin" -name 'libgodot-cpp*.a' | head -1)
	[ -n "$found" ] || { say "godot-cpp built but no library in $cpp_build/bin"; exit 1; }
	[ "$found" = "$cpp_lib" ] || cp "$found" "$cpp_lib"
	say "godot-cpp (arm64) built in $(( $(date +%s) - start )) s"
fi
flock -u 8

native_abs=$(abs "$NATIVE_DIR")
build_dir="$native_abs/build-android"
bin_dir="$native_abs/bin-android"
mkdir -p "$build_dir" "$bin_dir"
touch "$build_dir/.gdignore" "$bin_dir/.gdignore"   # never imported by the desktop project
if [ ! -e "$build_dir/CMakeCache.txt" ]; then
	run "$CMAKE" -S "$native_abs" -B "$build_dir" "${android_flags[@]}" -DTANK_NATIVE_PLATFORM=android \
		-DGODOTCPP_SRC="$src_abs" -DGODOTCPP_BUILD="$cpp_build" -DGODOTCPP_LIB="$cpp_lib" \
		-DTANK_NATIVE_GODOTCPP="$GODOTCPP_VERSION" -DTANK_NATIVE_BUILD_HOST="$(hostname) android-$ANDROID_API" \
		-DTANK_NATIVE_BIN="$bin_dir" -DTANK_NATIVE_FP_FLAGS="$NATIVE_FP_FLAGS" > "$build_dir/configure.log" 2>&1 \
		|| { tail -30 "$build_dir/configure.log"; say "configure FAILED"; exit 1; }
fi
run "$CMAKE" --build "$build_dir" -j"$NATIVE_JOBS" > "$build_dir/build.log" 2>&1 \
	|| { tail -40 "$build_dir/build.log"; say "build FAILED"; exit 1; }
so="$bin_dir/libtank_native.android.arm64.so"
[ -s "$so" ] || { say "built, but $so is missing"; exit 1; }
say "BUILT: $so ($(du -h "$so" | cut -f1)); $(file -b "$so" | cut -c1-80)"
# What the trig hazard looks like on this target: which libm symbols the library imports (bionic's, on a device).
say "libm imports: $("$ndk"/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm -D --undefined-only "$so" | grep -E ' (sin|cos|tan|atan2|atan|acos|asin|sqrt|log|exp|pow)f?$' | awk '{print $2}' | sort -u | tr '\n' ' ')"
