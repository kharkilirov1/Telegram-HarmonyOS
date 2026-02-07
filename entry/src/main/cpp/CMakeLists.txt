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
# After building TDLib for HarmonyOS, set TDLIB_DIR to the install path
if(DEFINED TDLIB_DIR)
    target_include_directories(tdlib_napi PRIVATE ${TDLIB_DIR}/include)
    target_link_libraries(tdlib_napi PUBLIC ${TDLIB_DIR}/lib/libtdjson.so)
else()
    message(WARNING "TDLIB_DIR not set. TDLib functions will use stub implementations.")
    target_compile_definitions(tdlib_napi PRIVATE TDLIB_STUB=1)
endif()
