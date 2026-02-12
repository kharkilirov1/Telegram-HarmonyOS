cmake_minimum_required(VERSION 3.16)
project(tdlib_napi)

set(CMAKE_CXX_STANDARD 17)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

# Add NAPI sources
add_library(tdlib_napi SHARED
    napi_init.cpp
    tdlib_napi.cpp
)

# HarmonyOS NAPI headers
target_include_directories(tdlib_napi PRIVATE
    ${NATIVERENDER_ROOT_PATH}
)

# Link against NAPI and TDLib
target_link_libraries(tdlib_napi PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
)

# ──────────────────────────────────────────────────────────────────────
# TDLib integration — SINGLE SOURCE OF TRUTH for the TDLib binary path.
#
# Priority:
#   1. -DTDLIB_DIR=<path> passed on cmake command line
#   2. TDLIB_DIR environment variable
#   3. Default: <this dir>/third_party/tdlib  (prebuilt binaries)
#
# NOTE: The repo-root tdlib/ submodule (.gitmodules) is for building
# TDLib from source. The *prebuilt* artifacts must be placed under
# third_party/tdlib/{include,lib/<abi>}. These are separate concerns.
# ──────────────────────────────────────────────────────────────────────
if(NOT DEFINED TDLIB_DIR)
    if(DEFINED ENV{TDLIB_DIR})
        set(TDLIB_DIR "$ENV{TDLIB_DIR}")
        message(STATUS "TDLIB_DIR from environment: ${TDLIB_DIR}")
    else()
        set(TDLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/tdlib")
    endif()
endif()
message(STATUS "TDLIB_DIR resolved to: ${TDLIB_DIR}")

set(TDLIB_ABI "${CMAKE_OHOS_ARCH_ABI}")
if(NOT TDLIB_ABI AND DEFINED OHOS_ARCH)
    set(TDLIB_ABI "${OHOS_ARCH}")
endif()

set(TDLIB_HEADER "${TDLIB_DIR}/include/td/telegram/td_json_client.h")
set(TDLIB_LIBRARY "${TDLIB_DIR}/lib/${TDLIB_ABI}/libtdjson.so")
set(TDLIB_RUNTIME_SONAME "libtdjson.so.1.8.61")

if(NOT EXISTS "${TDLIB_HEADER}" OR NOT EXISTS "${TDLIB_LIBRARY}")
    message(FATAL_ERROR
        "TDLib not found for ABI '${TDLIB_ABI}'.\n"
        "  Expected header:  ${TDLIB_HEADER}\n"
        "  Expected library: ${TDLIB_LIBRARY}\n"
        "Place prebuilt TDLib under ${TDLIB_DIR} or set -DTDLIB_DIR=<path>.")
endif()

message(STATUS "┌─ TDLib ────────────────────────────────────────")
message(STATUS "│ ABI:     ${TDLIB_ABI}")
message(STATUS "│ Header:  ${TDLIB_HEADER}")
message(STATUS "│ Library: ${TDLIB_LIBRARY}")
message(STATUS "│ SONAME:  ${TDLIB_RUNTIME_SONAME}")
message(STATUS "└────────────────────────────────────────────────")

target_include_directories(tdlib_napi PRIVATE "${TDLIB_DIR}/include")
target_link_libraries(tdlib_napi PUBLIC "${TDLIB_LIBRARY}")
target_compile_definitions(tdlib_napi PRIVATE
    TDLIB_DIR_PATH="${TDLIB_DIR}"
    TDLIB_SONAME="${TDLIB_RUNTIME_SONAME}"
)
# Ensure SONAME copy for runtime resolution
add_custom_command(TARGET tdlib_napi POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${TDLIB_LIBRARY}"
    "$<TARGET_FILE_DIR:tdlib_napi>/${TDLIB_RUNTIME_SONAME}"
)
