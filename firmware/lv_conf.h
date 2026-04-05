/**
 * LVGL 8.3 — aligned with SquareLine export (16 bpp, no swap).
 */
#ifndef LV_CONF_H
#define LV_CONF_H

#include <stdint.h>

#define LV_COLOR_DEPTH 16
#define LV_COLOR_16_SWAP 0

#define LV_MEM_CUSTOM 0
#define LV_MEM_SIZE (48U * 1024U)

#define LV_DISP_DEF_REFR_PERIOD 16
#define LV_INDEV_DEF_READ_PERIOD 16

#define LV_USE_LOG 0

#define LV_FONT_UNSCII_8 0
#define LV_FONT_MONTSERRAT_14 1
#define LV_FONT_DEFAULT &lv_font_montserrat_14

#define LV_USE_PERF_MONITOR 0
#define LV_USE_MEM_MONITOR 0

#define LV_USE_SPINNER 1

#define LV_USE_THEME_DEFAULT 1

#endif /* LV_CONF_H */
