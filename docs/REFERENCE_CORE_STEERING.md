# Reference Core Steering

This project should reuse as much as practical from two reference cores:

- OpenFPGA ZX Spectrum for Analogue Pocket integration.
- MiSTer Amstrad CPC for CPC hardware behavior.

For dock-specific keyboard handling, also consult `markus-zzz/myc64-pocket`
because it documents and implements the Pocket dock USB keyboard report layout
used by the APF controller words.

Do not treat either reference as loose inspiration when code can be copied,
adapted, or kept structurally equivalent. New local HDL should usually be glue
between those two worlds, not a fresh reimplementation of solved behavior.

## Decision Order

For every subsystem change:

1. Check whether the MiSTer Amstrad CPC core already implements the CPC-side
   behavior. If it does, preserve that logic and adapt only host/platform
   boundaries.
2. Check whether the ZX Spectrum Pocket core already implements the equivalent
   Analogue Pocket/APF pattern. If it does, copy or closely adapt that platform
   pattern.
3. For dock keyboard input, check `markus-zzz/myc64-pocket` before inventing an
   APF report interpretation. Its README and `src/bios/keyboard-ext.c` show the
   known working `cont3_key`/`cont3_joy`/`cont3_trig` layout.
4. Add new local code only when neither reference has the required boundary
   adapter, or when the references are incompatible and a small bridge is needed.
5. Document any deliberate divergence from either reference in the relevant
   source comment or docs file.

## Ownership Boundaries

The MiSTer Amstrad CPC core owns:

- Z80 timing and clock-enable relationships.
- Gate Array, CRTC, PPI, PSG, memory banking, model selection, and CPC reset
  behavior.
- CPC colour generation and palette mapping.
- FDC/u765, DSK, tape, expansion ROM, and snapshot behavior where imported.

The ZX Spectrum Pocket core owns the preferred shape for:

- APF top-level pin wiring and safe unused-interface handling.
- `core_top` port shape and bridge command integration.
- Scaler/DDIO video output structure, including registered RGB/DE/HS/VS output
  patterns.
- Asset/data-slot loading patterns such as `boot.rom`.
- Controller, virtual keyboard, platform metadata, release layout, and build
  project organization.
- Host-facing OSD and virtual-keyboard presentation. Prefer ZX's approach of
  rendering menu/keyboard graphics into an OSD bitmap RAM and keeping the live
  FPGA video compositor simple. Avoid adding wide per-pixel glyph or layout
  decode directly into the CPC video path unless it is only a temporary
  stepping stone.

The MyC64 Pocket core owns the preferred shape for:

- Dock USB keyboard APF report decoding: modifiers from `cont3_key[15:8]` and
  six HID usage bytes from `cont3_joy` plus `cont3_trig`.

Local PocketCPC code should own only:

- Adapters from APF bridge/data slots to MiSTer-style CPC host inputs.
- Adapters from MiSTer CPC video/audio/control outputs to APF outputs.
- Minimal storage wrappers needed to fit Pocket resources.
- Temporary debug/test harnesses, removed or clearly marked before release.

## Video-Specific Rule

Video work should preserve the MiSTer CPC colour path unless there is a proven
reason to diverge:

- Keep CPC Gate Array colour inputs, `color_mix`, mode tracking, and pixel-enable
  decisions aligned with MiSTer Amstrad.
- Use the ZX Spectrum Pocket core as the reference for APF-facing registered
  output, scaler clocking, JSON scaler metadata, and host-visible display mode
  behavior.
- If colour or phase issues appear on hardware, first compare against MiSTer
  `Amstrad.sv` plus `sys/video_mixer.sv`, and against ZX `core_top.sv`, before
  adding custom phase or palette logic.
- Treat the Pocket scaler/video pins as hardware-sensitive even when Quartus
  reports a clean compile. Current builds still warn that `cpc_apf_pixel_clk`
  and `cpc_apf_pixel_clk_90` are detected clocks without explicit clock
  assignments, so manual Pocket screenshots remain the final check for video
  changes until those constraints are tightened.

## Virtual Keyboard Rule

Virtual keyboard work should follow the ZX Spectrum Pocket core before local
innovation:

- Use ZX `src/firmware/main.c` and `src/firmware/main.h` as the reference for
  keyboard layout/state rendering.
- Use ZX `src/fpga/core/osdram.v` and the OSD RAM hookup in
  `src/fpga/core/core_top.sv` as the reference for overlay storage and
  compositing.
- Keep CPC key matrix behavior mapped from MiSTer CPC/PPI expectations, but
  keep the Pocket presentation/control-plane pattern structurally close to ZX.
- If an HDL-only overlay remains in use temporarily, keep it pipelined and
  ROM/RAM-backed. Do not grow a single-cycle combinational glyph renderer.

## Review Checklist

Before committing a subsystem change, answer these questions in the commit
message, PR notes, or nearby docs when relevant:

- Which reference core supplied the machine behavior?
- Which reference core supplied the Pocket/APF integration pattern?
- What local glue was necessary?
- What, if anything, deliberately differs from the reference cores?
