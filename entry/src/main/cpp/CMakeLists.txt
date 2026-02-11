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

# TDLib integration
# Uses bundled prebuilt TDLib by default, or external one if TDLIB_DIR is provided.
if(NOT DEFINED TDLIB_DIR)
    set(TDLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/tdlib")
endif()

set(TDLIB_ABI "${CMAKE_OHOS_ARCH_ABI}")
if(NOT TDLIB_ABI AND DEFINED OHOS_ARCH)
    set(TDLIB_ABI "${OHOS_ARCH}")
endif()

set(TDLIB_HEADER "${TDLIB_DIR}/include/td/telegram/td_json_client.h")
set(TDLIB_LIBRARY "${TDLIB_DIR}/lib/${TDLIB_ABI}/libtdjson.so")
set(TDLIB_RUNTIME_SONAME "libtdjson.so.1.8.61")

if(EXISTS "${TDLIB_HEADER}" AND EXISTS "${TDLIB_LIBRARY}")
    target_include_directories(tdlib_napi PRIVATE "${TDLIB_DIR}/include")
    target_link_libraries(tdlib_napi PUBLIC "${TDLIB_LIBRARY}")
    # libtdlib_napi depends on TDLib SONAME (libtdjson.so.1.8.61). Ensure this exact
    # filename is present next to native outputs so bundle packaging keeps runtime deps resolvable.
    add_custom_command(TARGET tdlib_napi POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${TDLIB_LIBRARY}"
        "$<TARGET_FILE_DIR:tdlib_napi>/${TDLIB_RUNTIME_SONAME}"
    )
    message(STATUS "Using TDLib for ABI ${TDLIB_ABI}: ${TDLIB_LIBRARY}")
else()
    # Release builds MUST have real TDLib — stub is only for development
    if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
        message(FATAL_ERROR
            "TDLib not found for ABI ${TDLIB_ABI} in release build. "
            "Place prebuilt TDLib at ${TDLIB_DIR}/lib/${TDLIB_ABI}/libtdjson.so "
            "and headers at ${TDLIB_DIR}/include/td/telegram/td_json_client.h")
    endif()
    message(WARNING "TDLib not found for ABI ${TDLIB_ABI}. Using stub implementations (dev only).")
    target_compile_definitions(tdlib_napi PRIVATE TDLIB_STUB=1)
endif()
