/**
 * Wiring GC9A01 (SPI) + tuning allineato al driver di riferimento (TFT_eSPI / HAL).
 *
 * Cablaggio attuale (SPI0 — GP18/19 sono SCK/MOSI hardware Pico):
 *   SCK  GP18   |  MOSI (“SDA”) GP19  |  RST GP20  |  DC GP21  |  CS GP22
 *   BL: non indicato → GP17 di default (cambia se il modulo usa altro pin).
 */
#ifndef BOARD_PINS_H
#define BOARD_PINS_H

#include "hardware/spi.h"

#define GC9A01_SPI_INST spi0

#define GC9A01_PIN_SCK  18
#define GC9A01_PIN_MOSI 19
#define GC9A01_PIN_MISO 16 /* SPI0 MISO; spesso non collegato al display */
#define GC9A01_PIN_CS   22
#define GC9A01_PIN_DC   21
#define GC9A01_PIN_RST  20
#define GC9A01_PIN_BL   17 /* backlight — adatta al tuo breakout */

/** 1 = backlight ON con GPIO alto */
#ifndef GC9A01_BL_ACTIVE_HIGH
#define GC9A01_BL_ACTIVE_HIGH 1
#endif

/**
 * Polarità DC come round_tft_ardu (hal_rp2040.c + hal_display.h):
 *   fase comando  → GPIO DC basso
 *   fase dati     → GPIO DC alto
 * Metti 1 solo se il tuo PCB inverte DC (comando = alto).
 */
#ifndef GC9A01_DC_CMD_IS_HIGH
#define GC9A01_DC_CMD_IS_HIGH 0
#endif

/** Righe nel buffer LVGL parziale (round_tft_ardu usa 20). */
#ifndef GC9A01_LVGL_BUF_LINES
#define GC9A01_LVGL_BUF_LINES 20
#endif

/** Dopo init batch (Bodmer / TFT_eSPI rotation 0 spesso 0x08 = MADCTL BGR). */
#ifndef GC9A01_MADCTL
#define GC9A01_MADCTL 0x08u
#endif

/** Scambia R↔B in RGB565 sul bus (0 = come ref. default). */
#ifndef GC9A01_SWAP_RB565
#define GC9A01_SWAP_RB565 0
#endif

/** 1 = invia prima il byte basso di ogni pixel 565. Ref. default 0 (MSB first). */
#ifndef GC9A01_SPI_565_LSB_FIRST
#define GC9A01_SPI_565_LSB_FIRST 0
#endif

/** Dopo MADCTL: 0 = niente; 1 = 0x21 INVON; 2 = 0x20 INVOFF (ref. GC9A01_COLOR_INVERSION). */
#ifndef GC9A01_COLOR_INVERSION
#define GC9A01_COLOR_INVERSION 0
#endif

#ifndef GC9A01_SPI_BAUD_HZ
#define GC9A01_SPI_BAUD_HZ (10 * 1000 * 1000)
#endif

#if GC9A01_DC_CMD_IS_HIGH
#define GC9A01_DC_FOR_CMD  1u
#define GC9A01_DC_FOR_DATA 0u
#else
#define GC9A01_DC_FOR_CMD  0u
#define GC9A01_DC_FOR_DATA 1u
#endif

#endif /* BOARD_PINS_H */
