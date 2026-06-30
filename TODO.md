# PocketCPC TODO

This file tracks the current roadmap in rough order of implementation cost, not
importance.

## Quick Wins

1. Custom CPC key <-> Pocket button mappings
   - Needed for games that expect keyboard controls instead of joystick input.
   - See `docs/INPUT_BINDING_PLAN.md` for the current UI/implementation
     recommendation and Pocket-framework constraints.

## Larger Features

2. Pocket save state support
   - Likely requires full machine-state serialization and restore, including
     CPC core state, RAM, FDC state, tape runtime state, and wrapper state.

3. Snapshot (`.sna`) saving
   - Lower value than Pocket save states.
   - Likely overlaps heavily with save-state capture work.

## Notes

- We only commit checkpoints after improvement is confirmed on hardware.
- We keep archived known-good `.rbf_r` files in
  `releases/known-good/` alongside git checkpoints.
