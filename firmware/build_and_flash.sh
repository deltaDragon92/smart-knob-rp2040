#!/usr/bin/env bash
# Build (CMake + Pico SDK) and flash RP2040 firmware (LVGL UI in ui/).
#
# Usage:
#   ./build_and_flash.sh              # configure (if needed), build, flash
#   ./build_and_flash.sh --copy-ui    # copy ui/*.c ui/*.h to project root (SquareLine flat export), then build+flash
#   ./build_and_flash.sh --no-flash   # build only
#   ./build_and_flash.sh --flash-only # flash existing UF2 (no build)
#
# Requires: CMake; Ninja (recommended) or Make; arm-none-eabi-gcc. Network on first configure (LVGL FetchContent via Git).
# PICO_SDK_PATH: export it, or .pico_sdk_path, or ~/.pico-sdk/sdk/<version>.
# PICO_TOOLCHAIN_PATH: export it (prefix with bin/arm-none-eabi-gcc), or .pico_toolchain_path, or install gcc on PATH / Homebrew opt paths.
#
# Optional device filter: export PICOTOOL_SER=<serial> or put one line in .picotool_serial (gitignored).
# Optional: PICOTOOL_BUS PICOTOOL_ADDRESS PICOTOOL_VID PICOTOOL_PID (hex), FLASH_UF2_WAIT, FLASH_UF2_BOOT_DELAY, FLASH_UF2_POLL
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
UF2_DEFAULT="$BUILD_DIR/display.uf2"
DO_COPY_UI=0
DO_BUILD=1
DO_FLASH=1

for arg in "$@"; do
  case "$arg" in
    --copy-ui) DO_COPY_UI=1 ;;
    --no-flash) DO_FLASH=0 ;;
    --flash-only) DO_BUILD=0 ;;
    -h|--help)
      head -n 22 "$0" | tail -n +2
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

copy_ui_to_root() {
  local SRC="$ROOT/ui"
  if [[ ! -d "$SRC" ]]; then
    echo "missing folder: $SRC" >&2
    return 1
  fi
  local n=0 f base
  for f in "$SRC"/*.c "$SRC"/*.h; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    cp "$f" "$ROOT/"
    echo "ok  $base"
    n=$((n + 1))
  done
  if [[ "$n" -eq 0 ]]; then
    echo "no top-level .c/.h in $SRC (subfolders are compiled via ui/CMakeLists.txt; skip --copy-ui)" >&2
    return 1
  fi
  echo "Copied $n file(s) to $ROOT"
}

# Directory that contains pico_sdk_init.cmake (not the repo root above it).
find_pico_sdk_path() {
  local p
  if [[ -n "${PICO_SDK_PATH:-}" ]]; then
    p="${PICO_SDK_PATH}"
    if [[ -f "$p/pico_sdk_init.cmake" ]]; then
      (cd "$p" && pwd)
      return 0
    fi
    echo "PICO_SDK_PATH is set but pico_sdk_init.cmake not found: $p" >&2
    return 1
  fi
  if [[ -f "$ROOT/.pico_sdk_path" ]]; then
    p="$(head -1 "$ROOT/.pico_sdk_path" | tr -d '[:space:]')"
    if [[ -n "$p" && -f "$p/pico_sdk_init.cmake" ]]; then
      (cd "$p" && pwd)
      return 0
    fi
    echo "Invalid path in $ROOT/.pico_sdk_path (need folder with pico_sdk_init.cmake): $p" >&2
    return 1
  fi
  if [[ -d "${HOME}/.pico-sdk/sdk" ]]; then
    while IFS= read -r p; do
      [[ -f "$p/pico_sdk_init.cmake" ]] || continue
      (cd "$p" && pwd)
      return 0
    done < <(find "${HOME}/.pico-sdk/sdk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -Vr)
  fi
  for p in "${HOME}/pico/pico-sdk" "${HOME}/pico-sdk"; do
    if [[ -f "$p/pico_sdk_init.cmake" ]]; then
      (cd "$p" && pwd)
      return 0
    fi
  done
  return 1
}

# Pico + LVGL need newlib headers (stdint.h, …). Homebrew `arm-none-eabi-gcc` is often gcc-only — reject without libc.
toolchain_has_newlib() {
  [[ -f "$1/arm-none-eabi/include/stdint.h" ]]
}

try_toolchain_prefix() {
  local p="$1"
  [[ -x "$p/bin/arm-none-eabi-gcc" ]] || return 1
  if toolchain_has_newlib "$p"; then
    (cd "$p" && pwd)
    return 0
  fi
  return 1
}

# Pico SDK expects PICO_TOOLCHAIN_PATH = install prefix (contains bin/arm-none-eabi-gcc and arm-none-eabi/include/…).
find_pico_toolchain_path() {
  local p g
  if [[ -n "${PICO_TOOLCHAIN_PATH:-}" ]]; then
    p="${PICO_TOOLCHAIN_PATH}"
    if try_toolchain_prefix "$p"; then
      return 0
    fi
    echo "PICO_TOOLCHAIN_PATH is set but is not a complete bare-metal toolchain (need bin/arm-none-eabi-gcc + arm-none-eabi/include/stdint.h): $p" >&2
    return 1
  fi
  if [[ -f "$ROOT/.pico_toolchain_path" ]]; then
    p="$(head -1 "$ROOT/.pico_toolchain_path" | tr -d '[:space:]')"
    if [[ -n "$p" ]] && try_toolchain_prefix "$p"; then
      return 0
    fi
    echo "Invalid path in $ROOT/.pico_toolchain_path (full ARM GNU toolchain prefix): $p" >&2
    return 1
  fi
  if [[ -d "${HOME}/.arm-gnu-toolchain" ]]; then
    while IFS= read -r g; do
      [[ -x "$g" ]] || continue
      p="$(cd "$(dirname "$g")/.." && pwd)"
      try_toolchain_prefix "$p" && return 0
    done < <(find "${HOME}/.arm-gnu-toolchain" -type f -path '*/bin/arm-none-eabi-gcc' 2>/dev/null | sort -Vr)
  fi
  if [[ -d "/Applications/ArmGNUToolchain" ]]; then
    while IFS= read -r g; do
      [[ -x "$g" ]] || continue
      p="$(cd "$(dirname "$g")/.." && pwd)"
      try_toolchain_prefix "$p" && return 0
    done < <(find /Applications/ArmGNUToolchain -type f -path '*/bin/arm-none-eabi-gcc' 2>/dev/null | sort -Vr)
  fi
  if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
    g="$(command -v arm-none-eabi-gcc)"
    g="$(cd "$(dirname "$g")" && pwd)/arm-none-eabi-gcc"
    p="$(cd "$(dirname "$(dirname "$g")")" && pwd)"
    if try_toolchain_prefix "$p"; then
      return 0
    fi
    echo "Found arm-none-eabi-gcc on PATH but without newlib (e.g. Homebrew gcc-only). Use a full ARM GNU toolchain." >&2
  fi
  for p in /opt/homebrew/opt/arm-none-eabi-gcc /usr/local/opt/arm-none-eabi-gcc \
           /opt/homebrew/opt/arm-gcc-bin /usr/local/opt/arm-gcc-bin; do
    try_toolchain_prefix "$p" && return 0
  done
  while IFS= read -r g; do
    [[ -x "$g" ]] || continue
    p="$(cd "$(dirname "$g")/.." && pwd)"
    try_toolchain_prefix "$p" && return 0
  done < <(find /opt/homebrew/opt /usr/local/opt -path '*/bin/arm-none-eabi-gcc' -type f 2>/dev/null | head -5)
  return 1
}

run_build() {
  local sdk tc cmake_extra=()
  sdk="$(find_pico_sdk_path)" || {
    echo "PICO_SDK_PATH is not set and no SDK was found automatically." >&2
    echo "  export PICO_SDK_PATH=\"\$HOME/.pico-sdk/sdk/2.2.0\"   # example" >&2
    echo "  or create $ROOT/.pico_sdk_path with that path on one line (gitignored)." >&2
    exit 1
  }
  export PICO_SDK_PATH="$sdk"
  echo "Using PICO_SDK_PATH=$PICO_SDK_PATH"

  tc="$(find_pico_toolchain_path)" || {
    echo "No complete ARM GNU bare-metal toolchain found (need arm-none-eabi-gcc + newlib headers under arm-none-eabi/include/)." >&2
    echo "  Homebrew \`brew install arm-none-eabi-gcc\` alone is not enough for Pico + LVGL." >&2
    echo "  Options:" >&2
    echo "    • brew install --cask gcc-arm-embedded   (installer; needs admin password)" >&2
    echo "    • Or extract the official tarball under ~/.arm-gnu-toolchain/ (see ARM GNU Toolchain downloads for darwin-arm64)." >&2
    echo "    • Then: export PICO_TOOLCHAIN_PATH=<prefix>   or one line in $ROOT/.pico_toolchain_path" >&2
    exit 1
  }
  export PICO_TOOLCHAIN_PATH="$tc"
  echo "Using PICO_TOOLCHAIN_PATH=$PICO_TOOLCHAIN_PATH"

  # Stale cache: e.g. project moved from firmware/display/ to firmware/ but build/ was kept.
  if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    local cached cr rr
    cached="$(grep -m1 '^CMAKE_HOME_DIRECTORY:INTERNAL=' "$BUILD_DIR/CMakeCache.txt" 2>/dev/null | cut -d= -f2- || true)"
    cr="$(cd "$cached" 2>/dev/null && pwd || true)"
    rr="$(cd "$ROOT" && pwd)"
    if [[ -n "$cr" && "$cr" != "$rr" ]]; then
      echo "CMake cache points to a different source tree; removing $BUILD_DIR" >&2
      echo "  was: $cr" >&2
      echo "  now: $rr" >&2
      rm -rf "$BUILD_DIR"
    fi
  fi

  if command -v ninja >/dev/null 2>&1; then
    cmake_extra+=(-G Ninja)
    echo "Using CMake generator: Ninja"
  fi

  cmake -S "$ROOT" -B "$BUILD_DIR" -DPICO_BOARD="${PICO_BOARD:-pico}" -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" "${cmake_extra[@]}" || exit 1
  cmake --build "$BUILD_DIR" --parallel || exit 1

  local elf="$BUILD_DIR/display.elf"
  if [[ -f "$elf" ]] && command -v python3 >/dev/null 2>&1 && [[ -f "$ROOT/scripts/fw_memory_report.py" ]]; then
    python3 "$ROOT/scripts/fw_memory_report.py" "$elf" 2>&1 || true
  fi
}

# --- Flash (picotool load, then UF2 volume fallback) ---
UF2="${FLASH_UF2_PATH:-$UF2_DEFAULT}"
WAIT_SEC="${FLASH_UF2_WAIT:-60}"
BOOT_DELAY="${FLASH_UF2_BOOT_DELAY:-0}"
POLL_INTERVAL="${FLASH_UF2_POLL:-0.05}"

find_picotool() {
  if [[ -n "${PICOTOOL:-}" && -x "$PICOTOOL" ]]; then
    echo "$PICOTOOL"
    return 0
  fi
  local candidates=(
    "${HOME}/.pico-sdk/picotool/2.2.0-a4/picotool/picotool"
    "${HOME}/.pico-sdk/picotool/2.0.0/picotool/picotool"
  )
  local p
  for p in "${candidates[@]}"; do
    [[ -x "$p" ]] && echo "$p" && return 0
  done
  if [[ -d "${HOME}/.pico-sdk/picotool" ]]; then
    while IFS= read -r p; do
      [[ -x "$p" ]] && echo "$p" && return 0
    done < <(find "${HOME}/.pico-sdk/picotool" -name picotool -type f 2>/dev/null)
  fi
  if command -v picotool >/dev/null 2>&1; then
    command -v picotool
    return 0
  fi
  return 1
}

run_flash() {
  if [[ ! -f "$UF2" ]]; then
    echo "UF2 not found: $UF2" >&2
    echo "Build first, or: $0 --flash-only with FLASH_UF2_PATH=/path/to/file.uf2" >&2
    exit 1
  fi

  local PT
  PT="$(find_picotool)" || PT=""
  if [[ -z "$PT" ]]; then
    echo "picotool not found. Set PICOTOOL=/path/to/picotool or install the Pico SDK." >&2
    if [[ "${FLASH_UF2_OPTIONAL:-}" == "1" ]]; then exit 0; fi
    exit 1
  fi

  if [[ -z "${PICOTOOL_SER:-}" && -f "$ROOT/.picotool_serial" ]]; then
    PICOTOOL_SER="$(head -1 "$ROOT/.picotool_serial" | tr -d '[:space:]')"
  fi

  local pt_sel=()
  [[ -n "${PICOTOOL_SER:-}" ]] && pt_sel+=(--ser "$PICOTOOL_SER")
  [[ -n "${PICOTOOL_BUS:-}" ]] && pt_sel+=(--bus "$PICOTOOL_BUS")
  [[ -n "${PICOTOOL_ADDRESS:-}" ]] && pt_sel+=(--address "$PICOTOOL_ADDRESS")
  [[ -n "${PICOTOOL_VID:-}" ]] && pt_sel+=(--vid "$PICOTOOL_VID")
  [[ -n "${PICOTOOL_PID:-}" ]] && pt_sel+=(--pid "$PICOTOOL_PID")

  echo "Using picotool: $PT"
  if [[ ${#pt_sel[@]} -gt 0 ]]; then
    echo "Device filter: ${pt_sel[*]}"
  else
    echo "No filter (--ser / .picotool_serial): picotool uses the first compatible Pico."
  fi

  local ELF="${UF2%.uf2}.elf"
  [[ "$ELF" == "$UF2" ]] && ELF="$BUILD_DIR/display.elf"

  write_flash_memory_snapshot() {
    if command -v python3 >/dev/null 2>&1 && [[ -f "$ROOT/scripts/fw_memory_report.py" ]] && [[ -f "$ELF" ]]; then
      python3 "$ROOT/scripts/fw_memory_report.py" "$ELF" --write-flash-snapshot "$ROOT" --quiet 2>/dev/null || true
    fi
  }

  fw_memory_report() {
    if [[ ! -f "$ELF" ]]; then
      return 0
    fi
    if command -v python3 >/dev/null 2>&1 && [[ -f "$ROOT/scripts/fw_memory_report.py" ]]; then
      python3 "$ROOT/scripts/fw_memory_report.py" "$ELF" 2>&1 || true
    fi
  }

  fw_memory_report

  local load_uf2_ok=false
  if [[ ${#pt_sel[@]} -eq 0 ]]; then
    if "$PT" load -x "$UF2" -f 2>&1; then load_uf2_ok=true; fi
  else
    if "$PT" load -x "$UF2" -f "${pt_sel[@]}" 2>&1; then load_uf2_ok=true; fi
  fi
  if [[ "$load_uf2_ok" == true ]]; then
    echo "OK — picotool load (UF2) completed."
    write_flash_memory_snapshot
    return 0
  fi

  if [[ -f "$ELF" ]] && [[ "$ELF" != "$UF2" ]]; then
    local load_elf_ok=false
    if [[ ${#pt_sel[@]} -eq 0 ]]; then
      if "$PT" load -x "$ELF" -f 2>&1; then load_elf_ok=true; fi
    else
      if "$PT" load -x "$ELF" -f "${pt_sel[@]}" 2>&1; then load_elf_ok=true; fi
    fi
    if [[ "$load_elf_ok" == true ]]; then
      echo "OK — picotool load (ELF) completed."
      write_flash_memory_snapshot
      return 0
    fi
  fi

  echo "picotool load failed; trying USB boot reboot (software BOOTSEL)…"

  local reboot_ok=false
  if [[ ${#pt_sel[@]} -eq 0 ]]; then
    if "$PT" reboot -u -f 2>&1; then reboot_ok=true; fi
  else
    if "$PT" reboot -u -f "${pt_sel[@]}" 2>&1; then reboot_ok=true; fi
  fi
  if [[ "$reboot_ok" != true ]]; then
    echo "picotool reboot -u -f failed: connect the Pico via USB (data cable)." >&2
    if [[ "${FLASH_UF2_OPTIONAL:-}" == "1" ]]; then exit 0; fi
    exit 1
  fi

  echo "Rebooted to UF2 mode; waiting for RPI-RP2 (max ${WAIT_SEC}s, poll ${POLL_INTERVAL}s)…"
  if awk -v d="${BOOT_DELAY:-0}" 'BEGIN { exit !(d > 0) }'; then
    sleep "$BOOT_DELAY"
  fi

  local os end VOL=""
  os="$(uname -s)"
  end=$(( $(date +%s) + WAIT_SEC ))
  while [[ $(date +%s) -lt $end ]]; do
    if [[ "$os" == "Darwin" ]]; then
      [[ -d "/Volumes/RPI-RP2" ]] && VOL="/Volumes/RPI-RP2" && break
    else
      for p in "/media/${USER}/RPI-RP2" /media/RPI-RP2 "/run/media/${USER}/RPI-RP2"; do
        [[ -d "$p" ]] && VOL="$p" && break
      done
      [[ -n "$VOL" ]] && break
      if [[ -n "${FLASH_UF2_VOL:-}" && -d "$FLASH_UF2_VOL" ]]; then
        VOL="$FLASH_UF2_VOL"
        break
      fi
    fi
    sleep "$POLL_INTERVAL"
  done

  if [[ -z "${VOL:-}" || ! -d "$VOL" ]]; then
    echo "Timeout: RPI-RP2 volume not found." >&2
    if [[ "${FLASH_UF2_OPTIONAL:-}" == "1" ]]; then
      echo "(FLASH_UF2_OPTIONAL=1: exiting without error.)" >&2
      exit 0
    fi
    echo "Try physical BOOTSEL (hold button while plugging in USB)." >&2
    exit 1
  fi

  local bn dst
  bn="$(basename "$UF2")"
  dst="$VOL/$bn"
  echo "Copying $bn → $VOL/"

  copy_uf2_to_volume() {
    local src="$1" d="$2"
    rm -f "$d" 2>/dev/null || true
    if cp "$src" "$d"; then
      return 0
    fi
    if [[ "$os" == "Darwin" ]] && command -v ditto >/dev/null 2>&1 && ditto "$src" "$d"; then
      return 0
    fi
    if dd "if=$src" "of=$d" bs=65536 2>/dev/null; then
      return 0
    fi
    return 1
  }

  if ! copy_uf2_to_volume "$UF2" "$dst"; then
    echo "ERROR: cannot write $dst (cp/ditto/dd failed)." >&2
    echo "On macOS: grant Full Disk Access to Terminal/Cursor (Settings → Privacy)." >&2
    if [[ "${FLASH_UF2_OPTIONAL:-}" == "1" ]]; then exit 0; fi
    exit 1
  fi

  sync 2>/dev/null || true
  echo "OK — UF2 copied; the Pico reboots with the new firmware."
  write_flash_memory_snapshot
}

if [[ "$DO_COPY_UI" -eq 1 ]]; then
  copy_ui_to_root || exit 1
fi

if [[ "$DO_BUILD" -eq 1 ]]; then
  run_build
fi

if [[ "$DO_FLASH" -eq 1 ]]; then
  run_flash
fi

echo "Done."
