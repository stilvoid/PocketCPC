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
   - The current defaults work, but they need another pass for better
     out-of-box choices.
   - Recheck the face-button, shoulder-button, and virtual-keyboard shortcuts
     against what CPC software most often expects.

3. Custom CPC key <-> Pocket button mappings
   - Needed for games that expect keyboard controls instead of joystick input.
   - Start with a bridge-backed runtime mapping table and a small set of
     persisted menu presets rather than trying to ship a full arbitrary remap
     UI in one step.

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

## Larger Features

7. Pocket save state support
   - Likely requires full machine-state serialization and restore, including
     CPC core state, RAM, FDC state, tape runtime state, and wrapper state.

8. Expansion ROM support
   - The boot bundle is currently fixed to the base ten 16 KiB ROM banks.
   - User-loadable expansion ROM pages still need a Pocket-facing design.

9. CPC 464 / CPC 664 as first-class user options
   - The ROM bundle already carries those machine ROMs.
   - The user-facing model-selection flow still needs finishing work and docs.

## Notes

- We only commit checkpoints after improvement is confirmed on hardware.
- Published build artifacts should live in GitHub Releases, not in git.
