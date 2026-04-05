cmake_minimum_required(VERSION 3.20)

if (NOT DEFINED PICO_BOARD)
    set(PICO_BOARD pico CACHE STRING "Board (e.g. pico, pico_w)")
endif ()

include(pico_sdk_import.cmake)

project(display_fw C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

include(FetchContent)
set(LV_CONF_PATH "${CMAKE_CURRENT_SOURCE_DIR}/lv_conf.h" CACHE STRING "" FORCE)
FetchContent_Declare(
    lvgl
    GIT_REPOSITORY https://github.com/lvgl/lvgl.git
    GIT_TAG v8.3.11
)
FetchContent_MakeAvailable(lvgl)

file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/geninclude/lvgl")
file(WRITE "${CMAKE_BINARY_DIR}/geninclude/lvgl/lvgl.h" "#include \"${lvgl_SOURCE_DIR}/lvgl.h\"\n")

# --- UI SquareLine: tutto qui — il file ui/CMakeLists.txt viene spesso sovrascritto dall'export e NON va usato
file(GLOB_RECURSE UI_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.c"
)
if (NOT UI_SOURCES)
    message(FATAL_ERROR "Nessun file .c in ui/. Esporta il progetto SquareLine nella cartella firmware/ui/")
endif ()

add_library(ui ${UI_SOURCES})
target_link_libraries(ui PUBLIC lvgl)
target_include_directories(ui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/ui
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}/geninclude
)
target_compile_definitions(ui PUBLIC LV_CONF_INCLUDE_SIMPLE)

add_executable(display
    main.cpp
    gc9a01_spi.c
)

target_include_directories(display PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/ui
    ${CMAKE_BINARY_DIR}/geninclude
)
target_compile_definitions(display PRIVATE LV_CONF_INCLUDE_SIMPLE)
target_link_libraries(display
    pico_stdlib
    hardware_spi
    hardware_gpio
    ui
    lvgl
)

pico_enable_stdio_usb(display 1)
pico_enable_stdio_uart(display 0)
pico_add_extra_outputs(display)
