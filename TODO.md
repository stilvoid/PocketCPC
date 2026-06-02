# PocketCPC TODO

This file tracks the current remaining work after the latest hardware-verified
release candidate.

## Near-Term

1. Complete Dock USB keyboard coverage
   - A few CPC-specific keys are still missing from the USB keyboard mapping.
   - `COPY` is the most obvious current gap and should get a sensible default.
   - After that, audit the remaining CPC-only keys and document the final map.

2. Review the default Pocket button bindings
   - The current defaults work, but they need another pass for better
     out-of-box choices.
   - Recheck the face-button, shoulder-button, and virtual-keyboard shortcuts
     against what CPC software most often expects.

3. Move the virtual keyboard to the top-right
   - Putting the VKB in the top-right should keep more of the active screen
     visible while typing.
   - Revisit the overlay position on both native and zoomed display modes.

4. Custom CPC key <-> Pocket button mappings
   - Needed for games that expect keyboard controls instead of joystick input.
   - Start with a bridge-backed runtime mapping table and a small set of
     persisted menu presets rather than trying to ship a full arbitrary remap
     UI in one step.

5. Persistent `.dsk` writes
   - Disk writes are currently fake-acknowledged for compatibility.
   - No sector changes are written back to the mounted image yet.

6. Restore snapshot saving
   - The current snapshot-save HDL path is not exposed in the public menu
     because it has not been proven reliable on Pocket hardware.
   - Validate the APF data-slot write/open-file flow before documenting this
     as an end-user feature.

7. Add an adapter-layer test harness
   - Cover the local APF bridge, data-slot, and input translation modules.
   - Use it to catch integration regressions before Pocket hardware testing.

## Larger Features

8. Pocket save state support
   - Likely requires full machine-state serialization and restore, including
     CPC core state, RAM, FDC state, tape runtime state, and wrapper state.

9. Expansion ROM support
   - The boot bundle is currently fixed to the base ten 16 KiB ROM banks.
   - User-loadable expansion ROM pages still need a Pocket-facing design.

10. CPC 464 / CPC 664 as first-class user options
   - The ROM bundle already carries those machine ROMs.
   - The user-facing model-selection flow still needs finishing work and docs.

## Notes

- We only commit checkpoints after improvement is confirmed on hardware.
- Published build artifacts should live in GitHub Releases, not in git.
