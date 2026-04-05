# smart-knob-rp2040

Firmware per **Raspberry Pi Pico** (RP2040) con display rotondo **GC9A01** 240×240, **LVGL 8.3** e interfaccia generata da **SquareLine Studio** (`firmware/ui/`).

## Cosa fa il codice

| Parte | Ruolo |
|--------|--------|
| **`firmware/main.cpp`** | Avvio: `stdio` USB, init hardware display (`gc9a01_hw_init`), LVGL (`lv_init`, `gc9a01_lvgl_port_init`), UI SquareLine (`ui_init`), loop con `lv_tick_inc` / `lv_timer_handler` ogni 5 ms. |
| **`firmware/gc9a01_spi.c`** | Driver SPI per GC9A01, sequenza di init allineata al riferimento round TFT / HAL, integrazione con il flush LVGL. |
| **`firmware/board_pins.h`** | Pin SPI0, CS/DC/RST/BL, polarità DC, baud SPI, righe buffer LVGL, `MADCTL` e altre macro di tuning colore/orientamento. |
| **`firmware/lv_conf.h`** | Configurazione LVGL per questo target. |
| **`firmware/ui/`** | File esportati da SquareLine (`.c`/`.h`); la libreria CMake `ui` è definita nel **`firmware/CMakeLists.txt`** principale (vedi sotto). |
| **`firmware/build_and_flash.sh`** | Trova Pico SDK e toolchain ARM, configura CMake, compila, genera `display.uf2`, flash con **picotool** (o copia UF2 su volume **RPI-RP2** in fallback). |
| **`firmware/scripts/fw_memory_report.py`** | Dopo la build (e dopo flash riuscito) può mostrare un riepilogo memoria flash/RAM dall’ELF. |

**CMake:** LVGL viene scaricato con `FetchContent` alla prima configurazione (serve rete). Il target eseguibile si chiama **`display`**; output: `firmware/build/display.uf2` (e `.elf`).

**Nota SquareLine:** il `CMakeLists.txt` che SquareLine può mettere in `ui/` **non** viene usato come `add_subdirectory`. Tutti i `ui/**/*.c` sono raccolti dal `CMakeLists.txt` in radice `firmware/`, così puoi ri-esportare l’UI senza rompere la build. Dettagli in `firmware/ui/SQUARELINE_EXPORT_README.txt`.

## Hardware (default)

Connessione consigliata su **SPI0** (Pico):

| Segnale | GPIO (default) |
|---------|----------------|
| SCK | 18 |
| MOSI | 19 |
| MISO | 16 (spesso non collegato al display) |
| CS | 22 |
| DC | 21 |
| RST | 20 |
| Backlight | 17 |

Modifica i define in **`firmware/board_pins.h`** se il tuo breakout usa altri pin o polarità DC/backlight.

## Prerequisiti

- **CMake** ≥ 3.20, **Ninja** (consigliato) o Make
- **Pico SDK** — imposta `PICO_SDK_PATH` oppure crea `firmware/.pico_sdk_path` con il percorso su una riga, oppure installa sotto `~/.pico-sdk/sdk/...`
- **Toolchain ARM GNU** completo (`arm-none-eabi-gcc` **e** newlib in `arm-none-eabi/include/`). Su macOS spesso non basta solo il pacchetto Homebrew “gcc-only”; vedi i messaggi di `build_and_flash.sh` per suggerimenti
- **picotool** (dal Pico SDK o su `PATH`) per flash via USB; in alternativa modalità UF2 manuale
- Prima configurazione: **Git** e rete per clonare LVGL

## Build e flash da terminale

Dalla cartella `firmware/`:

```bash
./build_and_flash.sh              # configure (se serve), build, flash
./build_and_flash.sh --no-flash   # solo build
./build_and_flash.sh --flash-only # solo flash (UF2 già presente)
./build_and_flash.sh --copy-ui    # copia ui/*.c e ui/*.h “flat” nella radice firmware (opzionale), poi build+flash
```

Variabili utili (estratti): `PICO_BOARD`, `BUILD_DIR`, `PICOTOOL`, `PICOTOOL_SER` o file `firmware/.picotool_serial`, `FLASH_UF2_PATH`, ecc. — vedi commenti in cima a `build_and_flash.sh`.

## Cursor / VS Code

- **Task predefinita Build** (`Cmd+Shift+B`): esegue `Firmware: build and flash` → `./build_and_flash.sh` da `firmware/`.
- **Esegui e debug**: configurazione **“Pico: build & flash”** (avvia uno script Node che lancia lo stesso comando nel terminale integrato).
- **CMake Tools:** in `.vscode/settings.json` è impostato `cmake.configureOnOpen: false` e la sorgente CMake è `firmware/`, per evitare richieste di kit all’apertura se usi solo lo script.

Estensione consigliata: CodeLLDB (per debug nativo in futuro); per build/flash non è obbligatoria.

## Struttura repository

```
firmware/
  CMakeLists.txt      # progetto Pico + LVGL + libreria ui
  main.cpp
  gc9a01_spi.c/.h
  board_pins.h
  lv_conf.h
  pico_sdk_import.cmake
  build_and_flash.sh
  ui/                 # export SquareLine
  scripts/            # fw_memory_report.py
.vscode/              # tasks, launch, settings
LICENSE
```

La cartella `firmware/build/` è in `.gitignore` (artifact di build e `_deps` LVGL).

## Licenza

Vedi [LICENSE](LICENSE) (MIT).
