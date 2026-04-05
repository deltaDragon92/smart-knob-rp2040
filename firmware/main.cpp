/**
 * Firmware entry: RP2040 + GC9A01 + LVGL + SquareLine UI (ui/).
 * Add your app logic here; keep hardware setup in gc9a01_spi.c / board_pins.h.
 */
#include "pico/stdlib.h"

extern "C" {
#include "lvgl/lvgl.h"
#include "ui.h"
#include "gc9a01_spi.h"
}

int main(void)
{
    stdio_init_all();

    gc9a01_hw_init();

    lv_init();
    gc9a01_lvgl_port_init();
    ui_init();

    const uint32_t tick_ms = 5;
    while (true) {
        lv_tick_inc(tick_ms);
        lv_timer_handler();
        sleep_ms(tick_ms);
    }
}
