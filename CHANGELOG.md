# Changelog

## v0.3.0

- Added experimental Pocket `Memories` support and sleep/wake restore using the same savestate path.
- Added `scripts/pocketcpc_savestate.py` to convert between PocketCPC `.sta` Memories and CPC `.sna` snapshots.
- Added `D-pad Mode` settings for `Joystick`, `Cursor Keys`, and `QAOP`.
- Added a virtual-keyboard-driven session remap flow so `A`, `B`, `X`, `Y`, `L`, `R`, and `Start` can be rebound to CPC keys or joystick actions until the next reset.
- Improved the virtual keyboard so it exposes joystick actions on-page, highlights active bindings, and shows remap state more clearly.
- Changed the default Pocket controls to more useful CPC-oriented bindings, including `B` as easy-reach joystick-up plus direct `Space`, `Return`, and `Escape` mappings on face buttons.
- Expanded the developer and architecture docs for input handling, savestates, and media transport ahead of release.

## v0.2.0

- Added Pocket menu machine model selection for `CPC 6128`, `CPC 664`, and `CPC 464`.
- The running CPC now pauses while the Pocket menu is open and resumes when the menu closes.
- Added a `Stereo Mix` menu option for the default 25% audio crossfeed.
- Improved Dock USB keyboard mappings, including `COPY`, keypad handling, and ISO/UK `#~` behavior.
- Added optional experimental `custom.rom` support as CPC upper ROM slot `6`.
- Improved virtual keyboard positioning and shortcut usability.
- Added a Quartus build report target to make release validation easier.
- Refined APF/video timing and internal integration code ahead of release.

## v0.1.0

- Initial release.
