# PocketCPC TODO

This file tracks the current remaining work after the latest hardware-verified
release candidate.

## Near-Term

1. Hardware-validate the Dock USB keyboard map
   - The current map now covers CPC-specific keys including `COPY`, keypad
     `Enter`, and `FDot`, with a compact-keyboard `Right Alt -> COPY` fallback.
   - Validate the ANSI grave and ISO non-US backslash choices for the CPC
     backslash key on real Dock hardware.
   - Keep docs honest if any keyboard-layout-specific compromises turn out to
     need adjustment.

2. Review the default Pocket button bindings
   - The current defaults and VKB-visible highlight state are in a much better
     place now, but they still need broader play-testing across real CPC games.
   - Recheck the face-button, shoulder-button, and virtual-keyboard shortcuts
     against what CPC software most often expects.

3. Custom CPC key <-> Pocket button mappings
   - A first session-only VKB-driven remap flow now exists for
     `A/B/X/Y/L/R/Start`.
   - VKB targets now cover both CPC keys and joystick directions/fire buttons,
     so games can be patched around missing joystick support without needing
     persisted profiles.
   - `D-pad Mode` now covers joystick, cursor keys, and `QAOP` for
     keyboard-only games that do not support joysticks.
   - The VKB now shows the effective current mappings directly, including
     default Pocket bindings for any buttons that have not been overridden.
   - Decide later whether persistent presets are worth the extra bridge/UI
     complexity; do not assume persistence is required.

4. Persistent `.dsk` writes
   - Disk writes are currently fake-acknowledged for compatibility.
   - No sector changes are written back to the mounted image yet.

5. Restore snapshot saving
   - The current snapshot-save HDL path is not exposed in the public menu
     because it has not been proven reliable on Pocket hardware.
   - Validate the APF data-slot write/open-file flow before documenting this
     as an end-user feature.

6. Add an adapter-layer test harness
   - Cover the local APF bridge, data-slot, and input translation modules.
   - Use it to catch integration regressions before Pocket hardware testing.
   - A first savestate-specific comparison harness now exists via
     `scripts/compare_sna_debug.py`; extend that into broader adapter coverage
     instead of starting from scratch.

## Larger Features

7. Pocket save state support
   - Keep the full Pocket-visible savestate blob staged in external PSRAM, not
     in Cyclone V BRAM and not as a live-streaming path.
   - Expand hardware validation of the PSRAM-backed path beyond the proven
     safe save/load/restart and basic sleep/wake cycles, especially FDC
     in-flight state, tape runtime position, and any remaining adapter-local
     state that should survive restore.
   - SNA v3 CRTC/GA timing state stabilized the tested sleep/wake display and
     CPC runtime state. If further edge cases appear, inspect remaining unsaved
     runtime state such as PSG internal counters and wrapper-local
     audio/interrupt latches before inventing another payload.
   - APF-native ROM setup loading now gives a visible Pocket progress bar and
     substantially improves tested wake latency. Keep `boot.rom` and
     `custom.rom` on the normal APF setup-write path unless hardware evidence
     proves a new need to change it.
   - Investigate whether Pocket-created Memory labels can ever reflect the
     last runtime-loaded `.sna`, `.dsk`, or `.cdt` media instead of the fixed
     `boot.rom` asset. If APF exposes no supported runtime content-title path,
     keep this documented as a Pocket UI limitation.
   - Maintain `docs/SAVESTATE_DEVLOG.md` as experiments confirm or eliminate
     design directions.

8. Expansion ROM support
   - An experimental first step now exists: optional `custom.rom` mapped to
     upper ROM slot `6`.
   - The broader multi-slot design still needs a Pocket-facing plan and likely
     external-memory work if it grows beyond a tiny number of BRAM-backed slots.

## Notes

- We only commit checkpoints after improvement is confirmed on hardware.
- Published build artifacts should live in GitHub Releases, not in git.
