# smart-knob-rp2040

RP2040 firmware for a round **GC9A01** 240×240 display, **LVGL 8.3**, and a **SquareLine** UI in `firmware/ui/`.

## First-time setup (after clone)

You do **not** need to clone LVGL manually. CMake downloads LVGL **v8.3.11** on the first configure (needs **Git** and **internet**).

1. **Clone this repo**
   ```bash
   git clone https://github.com/deltaDragon92/smart-knob-rp2040.git
   cd smart-knob-rp2040
   ```

2. **Install build tools**
   - **CMake** ≥ 3.20, **Ninja** (recommended), **Git**, **Python 3** (optional, for the memory report script)
   - **macOS (Homebrew):** `brew install cmake ninja git python3`
   - **Linux (Debian/Ubuntu):** `sudo apt install cmake ninja-build git python3 build-essential`

3. **Install the Raspberry Pi Pico SDK**  
   Follow the [official Getting started](https://datasheets.raspberrypi.com/pico/getting-started-with-pico.pdf) or clone [pico-sdk](https://github.com/raspberrypi/pico-sdk) and set:
   ```bash
   export PICO_SDK_PATH=/path/to/pico-sdk
   ```
   Alternatively put that path on one line in `firmware/.pico_sdk_path` (gitignored), or install the SDK under `~/.pico-sdk/sdk/<version>` so the build script can find it.

4. **Install a full ARM GNU toolchain** (not “compiler only”)  
   You need `arm-none-eabi-gcc` **and** newlib headers (`arm-none-eabi/include/stdint.h`, etc.).
   - **macOS:** the Homebrew `arm-none-eabi-gcc` formula is often incomplete for Pico + LVGL. Prefer the [ARM GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) tarball or `brew install --cask gcc-arm-embedded`, then:
     ```bash
     export PICO_TOOLCHAIN_PATH=/path/to/toolchain/prefix
     ```
     Or one line in `firmware/.pico_toolchain_path` (gitignored).

5. **picotool** (USB flash)  
   Build or install **picotool** from the Pico SDK and ensure it is on `PATH`, or rely on **UF2**: copy `firmware/build/display.uf2` to the **RPI-RP2** drive after BOOTSEL.

6. **Build (first run downloads LVGL)**
   ```bash
   cd firmware
   ./build_and_flash.sh --no-flash
   ```
   Fix any errors from the script (SDK path, toolchain). When it succeeds, `firmware/build/display.uf2` is ready.

7. **Flash the Pico**  
   Connect the board with a **data** USB cable, then:
   ```bash
   ./build_and_flash.sh
   ```
   Or use BOOTSEL + copy the UF2 file manually.

## What’s in the firmware

- **`main.cpp`** — init USB stdio, display, LVGL, SquareLine `ui_init()`, main LVGL tick loop.
- **`gc9a01_spi.c`** — GC9A01 over SPI, LVGL flush.
- **`board_pins.h`** — wiring and display tuning (SPI pins, DC polarity, buffer size, etc.).
- **`lv_conf.h`** — LVGL config.
- **`firmware/ui/`** — SquareLine export. The root **`firmware/CMakeLists.txt`** collects all `ui/**/*.c`; the `ui/CMakeLists.txt` from SquareLine is **ignored** so re-exports do not break the build (see `firmware/ui/SQUARELINE_EXPORT_README.txt`).
- **`build_and_flash.sh`** — configure, build, flash (picotool or UF2 fallback). Run `./build_and_flash.sh --help` for options.

## Default wiring (SPI0)

| Signal | GPIO |
|--------|------|
| SCK | 18 |
| MOSI | 19 |
| CS | 22 |
| DC | 21 |
| RST | 20 |
| Backlight | 17 |

Change pins in **`firmware/board_pins.h`** if your module differs.

## VS Code / Cursor

- **Build:** `Cmd+Shift+B` (default task) runs `./build_and_flash.sh` from `firmware/`.
- **Run and Debug:** choose **“Pico: build & flash”** (runs the same script in the integrated terminal).

## Layout

```
firmware/   CMake project, sources, ui/, build_and_flash.sh
.vscode/    tasks and launch configs
```

`firmware/build/` is gitignored (includes CMake `lvgl` fetch under `_deps/`).

## License

[MIT](LICENSE)
