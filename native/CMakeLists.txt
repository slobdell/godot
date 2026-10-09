# Tank Squad's native library (round 23, stream native): one shared library, libtank_native.linux.x86_64.so, built
# against a godot-cpp that `make native` (mk/native.mk) has already built per machine under .tools/. Driven by
# `make native`; the flags are the proof's (_agents/native.md "The flags and why"): -O2, no FMA contraction, no fast
# math, no -march, the same godot-cpp defines as the static library so the headers see one ABI.
cmake_minimum_required(VERSION 3.17)
project(tank_native LANGUAGES CXX)

set(GODOTCPP_SRC "" CACHE PATH "godot-cpp source tree (.tools/godot-cpp-<version>)")
set(GODOTCPP_BUILD "" CACHE PATH "that machine's godot-cpp build tree (bin/libgodot-cpp.*.a, gen/include)")
set(GODOTCPP_LIB "" CACHE FILEPATH "the godot-cpp static library")
set(TANK_NATIVE_GODOTCPP "unknown" CACHE STRING "godot-cpp version string, for build_info()")
set(TANK_NATIVE_BUILD_HOST "unknown" CACHE STRING "hostname the library is built on, for build_info()")
set(TANK_NATIVE_BIN "${CMAKE_SOURCE_DIR}/bin" CACHE PATH "where the .so goes (res://native/bin)")
set(TANK_NATIVE_FP_FLAGS "-O2 -ffp-contract=off -fno-fast-math" CACHE STRING "the numeric flags (mk/native.mk owns them)")
# Round 24 (stretch b): the platform. linux = the desktop library (the default, unchanged); android = arm64-v8a through
# the NDK's toolchain file (native/build_android.sh), the C++ runtime static through ANDROID_STL=c++_static.
set(TANK_NATIVE_PLATFORM "linux" CACHE STRING "linux | android")

foreach(v GODOTCPP_SRC GODOTCPP_BUILD GODOTCPP_LIB)
	if(NOT ${v})
		message(FATAL_ERROR "${v} must be given (run `make native`, not cmake by hand)")
	endif()
endforeach()

# godot-cpp, as built by mk/native.mk with the SAME flags: its PUBLIC usage requirements (cmake/godotcpp.cmake and
# cmake/linux.cmake in the godot-cpp tree) repeated here, since an imported library carries none.
add_library(godot-cpp STATIC IMPORTED)
set_target_properties(godot-cpp PROPERTIES IMPORTED_LOCATION "${GODOTCPP_LIB}")
target_include_directories(godot-cpp INTERFACE "${GODOTCPP_BUILD}/gen/include" "${GODOTCPP_SRC}/include")
if(TANK_NATIVE_PLATFORM STREQUAL "android")
	target_compile_definitions(godot-cpp INTERFACE GDEXTENSION DEBUG_ENABLED THREADS_ENABLED ANDROID_ENABLED UNIX_ENABLED)
	set(TANK_NATIVE_OUTPUT "tank_native.android.arm64")
else()
	target_compile_definitions(godot-cpp INTERFACE GDEXTENSION DEBUG_ENABLED THREADS_ENABLED LINUX_ENABLED UNIX_ENABLED)
	target_link_options(godot-cpp INTERFACE -static-libgcc -static-libstdc++)
	set(TANK_NATIVE_OUTPUT "tank_native.linux.x86_64")
endif()

add_library(tank_native SHARED src/register_types.cpp src/tank_native.cpp src/avoidance.cpp src/cover_native.cpp src/nav_native.cpp src/tank_record.cpp src/route_native.cpp src/drive_native.cpp src/situation_native.cpp src/matchups_native.cpp src/decide_native.cpp src/tq_native.cpp)
target_link_libraries(tank_native PRIVATE godot-cpp)
separate_arguments(TANK_NATIVE_FP_FLAGS_LIST UNIX_COMMAND "${TANK_NATIVE_FP_FLAGS}")
target_compile_options(tank_native PRIVATE ${TANK_NATIVE_FP_FLAGS_LIST} -fno-exceptions -fvisibility=hidden -Wall -Wextra -Wno-unused-parameter)
target_compile_definitions(tank_native PRIVATE
	NDEBUG
	TANK_NATIVE_GODOTCPP="${TANK_NATIVE_GODOTCPP}"
	TANK_NATIVE_BUILD_HOST="${TANK_NATIVE_BUILD_HOST}"
	TANK_NATIVE_FLAGS="${TANK_NATIVE_FP_FLAGS}")
set_target_properties(tank_native PROPERTIES
	CXX_STANDARD 17
	CXX_STANDARD_REQUIRED ON
	CXX_EXTENSIONS OFF
	POSITION_INDEPENDENT_CODE ON
	PREFIX "lib"
	OUTPUT_NAME "${TANK_NATIVE_OUTPUT}"
	LIBRARY_OUTPUT_DIRECTORY "${TANK_NATIVE_BIN}")
# No CMAKE_BUILD_TYPE: every optimisation flag is in TANK_NATIVE_FP_FLAGS, so nothing adds -O3 behind it.
set(CMAKE_CXX_FLAGS_RELEASE "" CACHE STRING "" FORCE)
