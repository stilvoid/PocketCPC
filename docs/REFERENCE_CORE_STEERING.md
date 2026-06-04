# Reference Core Steering

This project should reuse as much as practical from two reference cores:

- OpenFPGA ZX Spectrum for Analogue Pocket integration.
- MiSTer Amstrad CPC for CPC hardware behavior.

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
3. Add new local code only when neither reference has the required boundary
   adapter, or when the references are incompatible and a small bridge is needed.
4. Document any deliberate divergence from either reference in the relevant
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

## Review Checklist

Before committing a subsystem change, answer these questions in the commit
message, PR notes, or nearby docs when relevant:

- Which reference core supplied the machine behavior?
- Which reference core supplied the Pocket/APF integration pattern?
- What local glue was necessary?
- What, if anything, deliberately differs from the reference cores?
