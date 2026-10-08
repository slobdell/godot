#!/usr/bin/env bash
# Build Tank Squad's native library (round 23, stream native). Driven by `make native` (mk/native.mk), which passes
# everything through the environment; the why is in _agents/native.md.
#
#   1. godot-cpp's source, pinned by tag and sha256, under .tools/ (shared by every worktree on the machine, never rsynced);
#   2. the API dumped from OUR Godot binary (--dump-extension-api), so the binding matches the engine that runs it;
#   3. the binding built ONCE PER MACHINE AND FLAG SET under .tools/godot-cpp-<ver>/build-<key>/ (a flock: two worktrees
#      may ask at once), ccache when present, pinned to NATIVE_CPUS when given;
#   4. this worktree's extension (native/src) into native/build and native/bin, with a stamp of the host and the tree it
#      was built in: a .so that arrived by rsync from another machine is rebuilt, never trusted;
#   5. native/bin/tank_squad.gdextension written beside the .so, which is what switches the library ON for Godot.
#
# Exit 3 when there is no C++ toolchain (make decides whether that is a failure), non-zero on any build error.
set -euo pipefail

: "${GODOT:?the Godot binary}" "${TOOLS_DIR:?.tools}" "${DOWNLOADS:?.tools/downloads}"
: "${GODOTCPP_VERSION:?}" "${GODOTCPP_SHA256:?}" "${GODOTCPP_URL:?}" "${GODOTCPP_SRC:?}" "${GODOTCPP_BUILD:?}"
: "${GODOTCPP_LIB:?}" "${NATIVE_FP_FLAGS:?}" "${NATIVE_DIR:?}" "${NATIVE_BUILD:?}" "${NATIVE_BIN:?}" "${NATIVE_SO:?}"
: "${NATIVE_GDEXT:?}" "${NATIVE_JOBS:=4}" "${NATIVE_CPUS:=}" "${CMAKE:=cmake}"

say() { echo ">> native: $*"; }

for tool in "$CMAKE" c++ python3 tar curl sha256sum; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		say "no C++ toolchain here ($tool missing): the library is not built"
		exit 3
	fi
done

run() { # the compile commands, pinned when asked (builder0: NATIVE_CPUS=4-11 leaves the P-cores to perf-judge)
	if [ -n "$NATIVE_CPUS" ]; then taskset -c "$NATIVE_CPUS" "$@"; else "$@"; fi
}

launcher=()
if command -v ccache >/dev/null 2>&1; then launcher=(-DCMAKE_CXX_COMPILER_LAUNCHER=ccache); fi

abs() { python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1"; }
godot_abs=$(abs "$GODOT")
src_abs=$(abs "$GODOTCPP_SRC")
build_abs=$(abs "$GODOTCPP_BUILD")
lib_abs=$(abs "$GODOTCPP_LIB")

# ---- 1-3: the binding, once per machine, under a lock ---------------------------------------------------------
mkdir -p "$TOOLS_DIR"
exec 9>"$TOOLS_DIR/.godot-cpp.lock"
if ! flock -w 3600 9; then say "could not take $TOOLS_DIR/.godot-cpp.lock in an hour"; exit 1; fi

if [ ! -e "$GODOTCPP_SRC/.installed" ]; then
	say "downloading godot-cpp $GODOTCPP_VERSION"
	mkdir -p "$DOWNLOADS"
	tgz="$DOWNLOADS/godot-cpp-$GODOTCPP_VERSION.tar.gz"
	curl -fsSL --retry 3 -o "$tgz" "$GODOTCPP_URL"
	echo "$GODOTCPP_SHA256  $tgz" | sha256sum -c - >/dev/null
	rm -rf "$GODOTCPP_SRC"
	tar -xzf "$tgz" -C "$TOOLS_DIR"          # its top directory is godot-cpp-$GODOTCPP_VERSION
	[ -d "$GODOTCPP_SRC" ] || { say "the tarball did not unpack to $GODOTCPP_SRC"; exit 1; }
	rm -f "$tgz"
	touch "$GODOTCPP_SRC/.installed"
fi

api="$build_abs/api/extension_api.json"
if [ ! -s "$api" ] || [ "$godot_abs" -nt "$api" ]; then
	say "dumping the extension API from $(basename "$godot_abs")"
	mkdir -p "$build_abs/api"
	(cd "$build_abs/api" && "$godot_abs" --headless --dump-extension-api >/dev/null 2>&1)
	[ -s "$api" ] || { say "--dump-extension-api wrote nothing"; exit 1; }
fi

if [ ! -s "$lib_abs" ]; then
	say "building godot-cpp $GODOTCPP_VERSION ($NATIVE_FP_FLAGS; -j$NATIVE_JOBS${NATIVE_CPUS:+ on cpus $NATIVE_CPUS}; minutes the first time, ccache after)"
	start=$(date +%s)
	run "$CMAKE" -S "$src_abs" -B "$build_abs" -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE="-DNDEBUG" \
		-DCMAKE_CXX_FLAGS="$NATIVE_FP_FLAGS" -DGODOTCPP_TARGET=template_debug -DGODOTCPP_PRECISION=single \
		-DGODOTCPP_CUSTOM_API_FILE="$api" "${launcher[@]}" > "$build_abs/configure.log" 2>&1 \
		|| { tail -30 "$build_abs/configure.log"; say "godot-cpp configure FAILED (see $build_abs/configure.log)"; exit 1; }
	run "$CMAKE" --build "$build_abs" -j"$NATIVE_JOBS" > "$build_abs/build.log" 2>&1 \
		|| { tail -30 "$build_abs/build.log"; say "godot-cpp build FAILED (see $build_abs/build.log)"; exit 1; }
	[ -s "$lib_abs" ] || { say "godot-cpp built but $lib_abs is missing"; exit 1; }
	say "godot-cpp built in $(( $(date +%s) - start )) s"
fi
flock -u 9

# ---- 4-5: this worktree's extension --------------------------------------------------------------------------------
native_abs=$(abs "$NATIVE_DIR")
build_dir=$(abs "$NATIVE_BUILD")
bin_dir=$(abs "$NATIVE_BIN")
stamp_want="host=$(hostname) tree=$native_abs flags=$NATIVE_FP_FLAGS godot-cpp=$GODOTCPP_VERSION lib=$lib_abs"
if [ -e "$build_dir/.stamp" ] && [ "$(cat "$build_dir/.stamp")" != "$stamp_want" ]; then
	say "the build tree is another machine's or another flag set's ($(cat "$build_dir/.stamp")): rebuilding"
	rm -rf "$build_dir"
fi
if [ -e "$bin_dir/.built-on" ] && [ "$(cat "$bin_dir/.built-on")" != "$(hostname)" ]; then
	say "native/bin was built on $(cat "$bin_dir/.built-on"): rebuilding here"
	rm -rf "$build_dir" "$bin_dir"
fi
mkdir -p "$build_dir" "$bin_dir"
touch "$build_dir/.gdignore"            # Godot's scan never walks the objects; it must walk native/bin (the .gdextension)
echo "$stamp_want" > "$build_dir/.stamp"
if [ ! -e "$build_dir/CMakeCache.txt" ]; then
	run "$CMAKE" -S "$native_abs" -B "$build_dir" -DGODOTCPP_SRC="$src_abs" -DGODOTCPP_BUILD="$build_abs" \
		-DGODOTCPP_LIB="$lib_abs" -DTANK_NATIVE_GODOTCPP="$GODOTCPP_VERSION" -DTANK_NATIVE_BUILD_HOST="$(hostname)" \
		-DTANK_NATIVE_BIN="$bin_dir" -DTANK_NATIVE_FP_FLAGS="$NATIVE_FP_FLAGS" "${launcher[@]}" > "$build_dir/configure.log" 2>&1 \
		|| { tail -30 "$build_dir/configure.log"; say "configure FAILED (see $build_dir/configure.log)"; exit 1; }
fi
run "$CMAKE" --build "$build_dir" -j"$NATIVE_JOBS" > "$build_dir/build.log" 2>&1 \
	|| { tail -40 "$build_dir/build.log"; say "build FAILED (see $build_dir/build.log)"; exit 1; }
grep -E "warning:" "$build_dir/build.log" | head -20 || true
[ -s "$NATIVE_SO" ] || { say "built, but $NATIVE_SO is missing"; exit 1; }
hostname > "$bin_dir/.built-on"
cp "$NATIVE_DIR/tank_squad.gdextension.in" "$NATIVE_GDEXT"
say "ON: $NATIVE_SO ($(du -h "$NATIVE_SO" | cut -f1), $(hostname), $NATIVE_FP_FLAGS) and $NATIVE_GDEXT"
