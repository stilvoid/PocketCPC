# Implementation Plan

## Phase 0: Local setup and audit

1. Clone both upstream projects into `upstreams/`.
2. Confirm licences and keep notices.
3. Build the ZX Spectrum core unchanged, if possible, to confirm the local Quartus/APF toolchain.
4. Build MiSTer Amstrad if toolchain is available, or at least run lint/elaboration over the relevant HDL.
5. Produce an import list of MiSTer CPC files needed below `src/fpga/cpc/`.

Exit criteria:
- ZX Spectrum core compiles locally.
- CPC source dependency graph is known.
- New repository skeleton compiles with a dummy core.

## Phase 1: APF skeleton

1. Copy/adapt `apf_top.v` from the ZX Spectrum Pocket core.
2. Create `core_top.sv` with the same APF logical interface shape.
3. Tie off unused cart/link/IR/SRAM/SDRAM pins safely.
4. Generate a test pattern video output and silent/constant audio.
5. Add minimal core/platform JSON files.

Exit criteria:
- Pocket/Quartus project builds.
- Test pattern appears on Pocket or simulator harness.

## Phase 2: CPC machine import

1. Import MiSTer CPC HDL into `src/fpga/cpc/`.
2. Create `cpc_machine_pocket.sv`, a wrapper around the MiSTer CPC machine internals.
3. Remove or stub MiSTer-only features:
   - `hps_io`
   - `CONF_STR`
   - MiSTer scandoubler/HQ2x paths
   - SNAC/DB9
   - PS/2 direct input
4. Preserve CPC clocks, CPU enables, memory banking, CRTC, Gate Array, PPI, PSG.
5. Wire simple reset, model = CPC 6128, and default ROM/RAM.

Exit criteria:
- Design elaborates.
- Z80 leaves reset.
- CPC ROM fetches occur from the expected boot ROM address range.

## Phase 3: ROM asset loading

1. Define `boot.rom` bundle layout for CPC.
2. Implement APF bridge/slot loader to fill ROM storage at boot.
3. Map bundle offsets to:
   - CPC6128 OS
   - CPC6128 BASIC
   - AMSDOS
   - optional MF2
   - optional CPC464 OS/BASIC
   - optional CPC664 OS/BASIC/AMSDOS
4. Replace MiSTer `ioctl_*` ROM paths with Pocket asset-slot write paths.

Exit criteria:
- CPC boots to BASIC prompt with static ROM bundle.
- No DSK required.

## Phase 4: Input

1. Build CPC keyboard matrix adapter.
2. Map Pocket buttons to joystick and common keys.
3. Implement minimal virtual keyboard:
   - Select toggles keyboard overlay/mode.
   - D-pad moves selection.
   - A presses selected key.
   - X/Y or shoulder buttons toggle Shift/Ctrl as needed.
4. Add quick mappings for common CPC actions:
   - RUN/LOAD
   - Enter
   - Escape
   - Space
   - Cursor keys
   - Fire buttons

Exit criteria:
- User can type `CAT`, `RUN`, and basic commands.
- Joystick works in simple games.

## Phase 5: Video and audio

1. Adapt CPC RGB output to Pocket `video_rgb`.
2. Generate/align `video_rgb_clock` and `video_rgb_clock_90`.
3. Wire `video_de`, `video_hs`, `video_vs`.
4. Scale cleanly on Pocket screen, initially using one sensible mode.
5. Wire PSG audio into Pocket DAC path. Confirm signed/unsigned expectation.

Exit criteria:
- Stable image.
- Correct approximate colors.
- Audible PSG output.

## Phase 6: DSK read-only Drive A

1. Identify MiSTer CPC DSK block path.
2. Replace MiSTer sector request/ack transport with APF data-slot backed block cache.
3. Support `.dsk` in Drive A.
4. Make Drive B a stub until A works.
5. Ignore writes initially or report write-protect.

Exit criteria:
- `CAT` lists a mounted DSK.
- A simple disk game or utility loads.

## Phase 7: Robustness and feature expansion

1. Drive B support.
2. Disk write support.
3. CDT tape support.
4. CPC 464/664 models.
5. Expansion ROM slots.
6. Snapshot loading.
7. Display options.
8. Dock keyboard support if APF path is viable.
9. Timing closure and resource optimization.

Exit criteria:
- Public beta quality core.
