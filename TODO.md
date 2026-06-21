# PocketCPC TODO

This file tracks the current roadmap in rough order of implementation cost, not
importance.

## Current Focus

- [ ] Playfield zoom via Pocket OSD without regressing boot or video stability

## Quick Wins

1. Typing shortcuts on a virtual-keyboard page
  - Goal: inject common CPC commands without typing them character by
     character.
  - Initial targets: `|TAPE`, `|DISC`, `CAT`, `RUN"`, `RUN"DISC"`.
  - Current status: confirmed working on hardware, including appended Return.

2. Optional zoom mode for the main CPC playfield
  - Crop away most of the border/overscan area for games that do not use it.
  - Keep normal full-border mode available.
  - Implement as a Pocket core menu option, not as a virtual-keyboard key.
  - Current status: previous attempt regressed video output and was removed.
    Re-implement using the ZX Pocket display/control pattern rather than a
    CPC-specific ad hoc crop path.

3. Custom CPC key <-> Pocket button mappings
   - Needed for games that expect keyboard controls instead of joystick input.

## Larger Features

4. Pocket save state support
   - Likely requires full machine-state serialization and restore, including
     CPC core state, RAM, FDC state, tape runtime state, and wrapper state.

5. Snapshot (`.sna`) saving
   - Lower value than Pocket save states.
   - Likely overlaps heavily with save-state capture work.

## Notes

- 64K snapshot loading is good enough for now and should be tested further over
  time with a wider set of `.sna` files.
- We only commit checkpoints after improvement is confirmed on hardware.
- We keep archived known-good `.rbf_r` files in
  `releases/known-good/` alongside git checkpoints.
