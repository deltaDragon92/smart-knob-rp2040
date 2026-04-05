/**
 * GC9A01 240×240 + LVGL 8 — allineato a round_tft_ardu:
 *   gc9a01_lcd.c (init batch, set_window, RGB565) + hal_rp2040 (DC: cmd=LOW, data=HIGH).
 */
#include "gc9a01_spi.h"
#include "board_pins.h"

#include "hardware/gpio.h"
#include "hardware/spi.h"
#include "pico/stdlib.h"

#include "lvgl/lvgl.h"

#define GC9A01_WIDTH 240
#define GC9A01_HEIGHT 240
#define BUF_LINES GC9A01_LVGL_BUF_LINES

#define GC9A01_CASET  0x2Au
#define GC9A01_RASET  0x2Bu
#define GC9A01_RAMWR  0x2Cu
#define GC9A01_SLPOUT 0x11u
#define GC9A01_DISPON 0x29u
#define GC9A01_SLPOUT_DELAY_MS 120u

typedef enum {
    BEGIN_WRITE = 0,
    WRITE_COMMAND_8 = 1,
    WRITE_COMMAND_16 = 2,
    WRITE_COMMAND_BYTES = 3,
    WRITE_DATA_8 = 4,
    WRITE_DATA_16 = 5,
    WRITE_BYTES = 6,
    WRITE_C8_D8 = 7,
    WRITE_C8_D16 = 8,
    WRITE_C8_BYTES = 9,
    WRITE_C16_D16 = 10,
    END_WRITE = 11,
    DELAY = 12,
} spi_op_t;

/* Tabella identica al ref. utente (B6 0x00,0x20; 0x36 solo dopo batch; MADCTL separato). */
static const uint8_t gc9a01_init_operations[] = {
    BEGIN_WRITE,
    WRITE_COMMAND_8,
    0xEF,
    WRITE_C8_D8,
    0xEB,
    0x14,
    WRITE_COMMAND_8,
    0xFE,
    WRITE_COMMAND_8,
    0xEF,
    WRITE_C8_D8,
    0xEB,
    0x14,
    WRITE_C8_D8,
    0x84,
    0x40,
    WRITE_C8_D8,
    0x85,
    0xFF,
    WRITE_C8_D8,
    0x86,
    0xFF,
    WRITE_C8_D8,
    0x87,
    0xFF,
    WRITE_C8_D8,
    0x88,
    0x0A,
    WRITE_C8_D8,
    0x89,
    0x21,
    WRITE_C8_D8,
    0x8A,
    0x00,
    WRITE_C8_D8,
    0x8B,
    0x80,
    WRITE_C8_D8,
    0x8C,
    0x01,
    WRITE_C8_D8,
    0x8D,
    0x01,
    WRITE_C8_D8,
    0x8E,
    0xFF,
    WRITE_C8_D8,
    0x8F,
    0xFF,
    WRITE_C8_D16,
    0xB6,
    0x00,
    0x20,
    WRITE_C8_D8,
    0x3A,
    0x05,
    WRITE_COMMAND_8,
    0x90,
    WRITE_BYTES,
    4,
    0x08,
    0x08,
    0x08,
    0x08,
    WRITE_C8_D8,
    0xBD,
    0x06,
    WRITE_C8_D8,
    0xBC,
    0x00,
    WRITE_COMMAND_8,
    0xFF,
    WRITE_BYTES,
    3,
    0x60,
    0x01,
    0x04,
    WRITE_C8_D8,
    0xC3,
    0x13,
    WRITE_C8_D8,
    0xC4,
    0x13,
    WRITE_C8_D8,
    0xC9,
    0x22,
    WRITE_C8_D8,
    0xBE,
    0x11,
    WRITE_C8_D16,
    0xE1,
    0x10,
    0x0E,
    WRITE_COMMAND_8,
    0xDF,
    WRITE_BYTES,
    3,
    0x21,
    0x0c,
    0x02,
    WRITE_COMMAND_8,
    0xF0,
    WRITE_BYTES,
    6,
    0x45,
    0x09,
    0x08,
    0x08,
    0x26,
    0x2A,
    WRITE_COMMAND_8,
    0xF1,
    WRITE_BYTES,
    6,
    0x43,
    0x70,
    0x72,
    0x36,
    0x37,
    0x6F,
    WRITE_COMMAND_8,
    0xF2,
    WRITE_BYTES,
    6,
    0x45,
    0x09,
    0x08,
    0x08,
    0x26,
    0x2A,
    WRITE_COMMAND_8,
    0xF3,
    WRITE_BYTES,
    6,
    0x43,
    0x70,
    0x72,
    0x36,
    0x37,
    0x6F,
    WRITE_C8_D16,
    0xED,
    0x1B,
    0x0B,
    WRITE_C8_D8,
    0xAE,
    0x77,
    WRITE_C8_D8,
    0xCD,
    0x63,
    WRITE_COMMAND_8,
    0x70,
    WRITE_BYTES,
    9,
    0x07,
    0x07,
    0x04,
    0x0E,
    0x0F,
    0x09,
    0x07,
    0x08,
    0x03,
    WRITE_C8_D8,
    0xE8,
    0x34,
    WRITE_COMMAND_8,
    0x62,
    WRITE_BYTES,
    12,
    0x18,
    0x0D,
    0x71,
    0xED,
    0x70,
    0x70,
    0x18,
    0x0F,
    0x71,
    0xEF,
    0x70,
    0x70,
    WRITE_COMMAND_8,
    0x63,
    WRITE_BYTES,
    12,
    0x18,
    0x11,
    0x71,
    0xF1,
    0x70,
    0x70,
    0x18,
    0x13,
    0x71,
    0xF3,
    0x70,
    0x70,
    WRITE_COMMAND_8,
    0x64,
    WRITE_BYTES,
    7,
    0x28,
    0x29,
    0xF1,
    0x01,
    0xF1,
    0x00,
    0x07,
    WRITE_COMMAND_8,
    0x66,
    WRITE_BYTES,
    10,
    0x3C,
    0x00,
    0xCD,
    0x67,
    0x45,
    0x45,
    0x10,
    0x00,
    0x00,
    0x00,
    WRITE_COMMAND_8,
    0x67,
    WRITE_BYTES,
    10,
    0x00,
    0x3C,
    0x00,
    0x00,
    0x00,
    0x01,
    0x54,
    0x10,
    0x32,
    0x98,
    WRITE_COMMAND_8,
    0x74,
    WRITE_BYTES,
    7,
    0x10,
    0x85,
    0x80,
    0x00,
    0x00,
    0x4E,
    0x00,
    WRITE_C8_D16,
    0x98,
    0x3e,
    0x07,
    WRITE_COMMAND_8,
    0x35,
    WRITE_COMMAND_8,
    0x21,
    WRITE_COMMAND_8,
    GC9A01_SLPOUT,
    END_WRITE,
    DELAY,
    GC9A01_SLPOUT_DELAY_MS,
    BEGIN_WRITE,
    WRITE_COMMAND_8,
    GC9A01_DISPON,
    END_WRITE,
    DELAY,
    20,
};

static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf1[GC9A01_WIDTH * BUF_LINES];
static lv_disp_drv_t disp_drv;

static uint8_t gc9a01_px_chunk[512];

static void gc9a01_bl_set(int on)
{
    const int level = on ? (GC9A01_BL_ACTIVE_HIGH ? 1 : 0) : (GC9A01_BL_ACTIVE_HIGH ? 0 : 1);
    gpio_put(GC9A01_PIN_BL, level);
}

static inline void cs_low(void)
{
    gpio_put(GC9A01_PIN_CS, 0);
}

static inline void cs_high(void)
{
    gpio_put(GC9A01_PIN_CS, 1);
}

static inline void write_cmd_byte(uint8_t c)
{
    gpio_put(GC9A01_PIN_DC, GC9A01_DC_FOR_CMD);
    spi_write_blocking(GC9A01_SPI_INST, &c, 1);
}

static inline void write_data_byte(uint8_t b)
{
    gpio_put(GC9A01_PIN_DC, GC9A01_DC_FOR_DATA);
    spi_write_blocking(GC9A01_SPI_INST, &b, 1);
}

static void run_init_batch(const uint8_t *operations, size_t len)
{
    for (size_t i = 0; i < len; ++i) {
        uint8_t l = 0;
        switch (operations[i]) {
        case WRITE_C8_D16:
            l++;
            /* fall through */
        case WRITE_C8_D8:
            l++;
            /* fall through */
        case WRITE_COMMAND_8:
            write_cmd_byte(operations[++i]);
            break;
        case WRITE_C16_D16:
            l = 2;
            /* fall through */
        case WRITE_COMMAND_16: {
            uint8_t msb = operations[++i];
            uint8_t lsb = operations[++i];
            write_cmd_byte(msb);
            write_cmd_byte(lsb);
            break;
        }
        case WRITE_COMMAND_BYTES:
            l = operations[++i];
            while (l--)
                write_cmd_byte(operations[++i]);
            l = 0;
            break;
        case WRITE_DATA_8:
            l = 1;
            break;
        case WRITE_DATA_16:
            l = 2;
            break;
        case WRITE_BYTES:
            l = operations[++i];
            break;
        case WRITE_C8_BYTES:
            write_cmd_byte(operations[++i]);
            l = operations[++i];
            break;
        case BEGIN_WRITE:
            cs_low();
            break;
        case END_WRITE:
            cs_high();
            break;
        case DELAY:
            sleep_ms(operations[++i]);
            break;
        default:
            break;
        }
        while (l--)
            write_data_byte(operations[++i]);
    }
}

static inline uint16_t rgb565_swap_rb(uint16_t c)
{
    return (uint16_t)(((c & 0x001Fu) << 11) | (c & 0x07E0u) | ((c & 0xF800u) >> 11));
}

static void madctl_and_inversion(void)
{
    cs_low();
    write_cmd_byte(0x36u);
    write_data_byte((uint8_t)GC9A01_MADCTL);
    cs_high();

#if GC9A01_COLOR_INVERSION == 1
    cs_low();
    write_cmd_byte(0x21u);
    cs_high();
#elif GC9A01_COLOR_INVERSION == 2
    cs_low();
    write_cmd_byte(0x20u);
    cs_high();
#endif
}

/** Finestra + RAMWR; CS resta basso per i pixel (flush). */
static void set_window_open_write(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1)
{
    uint8_t xb[4] = {(uint8_t)(x0 >> 8), (uint8_t)(x0 & 0xFFu), (uint8_t)(x1 >> 8), (uint8_t)(x1 & 0xFFu)};
    uint8_t yb[4] = {(uint8_t)(y0 >> 8), (uint8_t)(y0 & 0xFFu), (uint8_t)(y1 >> 8), (uint8_t)(y1 & 0xFFu)};

    cs_low();
    write_cmd_byte((uint8_t)GC9A01_CASET);
    gpio_put(GC9A01_PIN_DC, GC9A01_DC_FOR_DATA);
    spi_write_blocking(GC9A01_SPI_INST, xb, 4);

    write_cmd_byte((uint8_t)GC9A01_RASET);
    gpio_put(GC9A01_PIN_DC, GC9A01_DC_FOR_DATA);
    spi_write_blocking(GC9A01_SPI_INST, yb, 4);

    write_cmd_byte((uint8_t)GC9A01_RAMWR);
    gpio_put(GC9A01_PIN_DC, GC9A01_DC_FOR_DATA);
}

static void flush_cb(lv_disp_drv_t *drv, const lv_area_t *area, lv_color_t *color_p)
{
    const int32_t w = area->x2 - area->x1 + 1;
    const int32_t h = area->y2 - area->y1 + 1;

    set_window_open_write((uint16_t)area->x1, (uint16_t)area->y1, (uint16_t)area->x2, (uint16_t)area->y2);

    for (int32_t row = 0; row < h; row++) {
        const lv_color_t *rp = color_p + row * w;
        uint32_t col = 0;
        while (col < (uint32_t)w) {
            uint32_t n = (uint32_t)w - col;
            if (n > sizeof(gc9a01_px_chunk) / 2u)
                n = sizeof(gc9a01_px_chunk) / 2u;
            size_t k = 0;
            for (uint32_t j = 0; j < n; j++) {
                uint16_t c = rp[col + j].full;
#if GC9A01_SWAP_RB565
                c = rgb565_swap_rb(c);
#endif
#if GC9A01_SPI_565_LSB_FIRST
                gc9a01_px_chunk[k++] = (uint8_t)(c & 0xFFu);
                gc9a01_px_chunk[k++] = (uint8_t)(c >> 8);
#else
                gc9a01_px_chunk[k++] = (uint8_t)(c >> 8);
                gc9a01_px_chunk[k++] = (uint8_t)(c & 0xFFu);
#endif
            }
            spi_write_blocking(GC9A01_SPI_INST, gc9a01_px_chunk, k);
            col += n;
        }
    }

    cs_high();
    lv_disp_flush_ready(drv);
}

void gc9a01_hw_init(void)
{
    gpio_init(GC9A01_PIN_CS);
    gpio_set_dir(GC9A01_PIN_CS, GPIO_OUT);
    cs_high();

    gpio_init(GC9A01_PIN_DC);
    gpio_set_dir(GC9A01_PIN_DC, GPIO_OUT);

    gpio_init(GC9A01_PIN_RST);
    gpio_set_dir(GC9A01_PIN_RST, GPIO_OUT);
    gpio_put(GC9A01_PIN_RST, 1);

    gpio_init(GC9A01_PIN_BL);
    gpio_set_dir(GC9A01_PIN_BL, GPIO_OUT);
    gc9a01_bl_set(0);

    spi_init(GC9A01_SPI_INST, GC9A01_SPI_BAUD_HZ);
    spi_set_format(GC9A01_SPI_INST, 8, SPI_CPOL_0, SPI_CPHA_0, SPI_MSB_FIRST);

    gpio_set_function(GC9A01_PIN_SCK, GPIO_FUNC_SPI);
    gpio_set_function(GC9A01_PIN_MOSI, GPIO_FUNC_SPI);
    /* Come hal_rp2040: solo SCK+MOSI; MISO non serve al display */

    /* hal_display_reset_pulse() */
    sleep_ms(10);
    gpio_put(GC9A01_PIN_RST, 0);
    sleep_ms(10);
    gpio_put(GC9A01_PIN_RST, 1);
    sleep_ms(120);

    run_init_batch(gc9a01_init_operations, sizeof(gc9a01_init_operations));
    madctl_and_inversion();

    gc9a01_bl_set(1);
}

void gc9a01_lvgl_port_init(void)
{
    lv_disp_draw_buf_init(&draw_buf, buf1, NULL, GC9A01_WIDTH * BUF_LINES);
    lv_disp_drv_init(&disp_drv);
    disp_drv.hor_res = GC9A01_WIDTH;
    disp_drv.ver_res = GC9A01_HEIGHT;
    disp_drv.flush_cb = flush_cb;
    disp_drv.draw_buf = &draw_buf;
    lv_disp_drv_register(&disp_drv);
}
