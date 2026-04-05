# Minimal Pico SDK bootstrap: set PICO_SDK_PATH to your SDK checkout, or export the env var.
if (DEFINED ENV{PICO_SDK_PATH} AND (NOT PICO_SDK_PATH))
    set(PICO_SDK_PATH $ENV{PICO_SDK_PATH})
endif ()

if (NOT PICO_SDK_PATH)
    message(FATAL_ERROR "PICO_SDK_PATH is not set. Export PICO_SDK_PATH or pass -DPICO_SDK_PATH=... to CMake.")
endif ()

get_filename_component(PICO_SDK_PATH "${PICO_SDK_PATH}" REALPATH BASE_DIR "${CMAKE_BINARY_DIR}")
include("${PICO_SDK_PATH}/pico_sdk_init.cmake")
