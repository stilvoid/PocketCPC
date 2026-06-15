# PocketCPC Developer Guide

This guide is for a developer who already knows how to program, but is new to:

- FPGA development
- Verilog/SystemVerilog
- Analogue Pocket/openFPGA cores
- the Amstrad CPC hardware model used by this project

The goal is not to teach all of digital design. The goal is to make this repository readable. You should be able to use this document as a map while exploring the code.

## Glossary

This glossary covers terms used in this document that may be unfamiliar if you mostly come from software.

### `always` block

A block of Verilog that describes logic which continuously exists in hardware. An `always @(posedge clk)` block usually describes state updated on a clock edge. An `always @(*)` block usually describes combinational logic.

### `APF`

Analogue Pocket Framework. This is Analogue's platform interface for openFPGA cores. In practice, it means the top-level hardware conventions, bridge protocol, metadata files, and scaler/audio interfaces a core must follow to run on the Pocket.

### `block RAM` / `BRAM`

Dedicated memory resources built into the FPGA chip. These are used for things like ROMs, RAMs, buffers, and frame-related storage. They are not the same thing as allocating a normal software array in system RAM.

### `bridge`

The communication path between the Pocket host environment and the user core running in the FPGA. In this project it is used for control/status, data-slot requests, and host-delivered data buffers.

### `clock domain`

A region of the design driven by a particular clock. If two parts of a design use different clocks, they are in different clock domains and need explicit synchronization when they communicate.

### `clock enable`

A signal that tells logic to update only on selected clock cycles while still using the same underlying clock. This is often used instead of creating many separate clocks.

### `combinational logic`

Logic whose outputs are a direct function of its current inputs, with no stored state. In Verilog this is often written with `assign` statements or `always @(*)` blocks.

### `core`

In this context, the FPGA implementation of a hardware system, here an Amstrad CPC for the Analogue Pocket.

### `data slot`

An APF mechanism for host-provided files or blobs of data, such as `boot.rom` or a mounted disk image. A core can request reads from these slots through the APF command system.

### `DDR output`

Double-data-rate output. The Pocket video interface uses DDR signaling to send more bits per clock edge toward the scaler.

### `flip-flop`

A hardware storage element that remembers a bit of state, usually updated on a clock edge. Registers in HDL are often implemented using banks of flip-flops.

### `FPGA`

Field-programmable gate array. A chip that can be configured to behave like a custom digital circuit. Instead of running software instructions in sequence, it implements hardware structures directly.

### `Gate Array`

For the CPC specifically, the custom hardware block that helps coordinate timing, video mode behavior, memory timing, interrupts, and other machine-level behavior. In this repo it appears as the imported `ga40010` logic.

### `HDL`

Hardware description language. A language used to describe digital hardware. Verilog and SystemVerilog are HDLs.

### `host`

The Pocket-side environment outside the user core. It manages things like file mounting, bridge transactions, metadata, and initial control flow.

### `metastability`

A hardware hazard that can happen when a signal crosses clock domains without proper synchronization. The result can be unpredictable sampling behavior. Synchronizer modules help reduce this risk.

### `module`

The main unit of structure in Verilog. A module is roughly analogous to a component or class instance boundary, but it describes hardware and ports rather than a software object model.

### `openFPGA`

Analogue's platform for third-party FPGA cores on the Pocket.

### `PLL`

Phase-locked loop. A hardware clock-generation block used to derive one clock from another. In this project it is used to generate the CPC machine clock from the Pocket input clock.

### `PS/2`

An older keyboard protocol. This project reuses imported CPC keyboard logic that expects PS/2-style key events, so Pocket inputs are translated into that format.

### `QSF`

Quartus Settings File. Intel Quartus uses this project file to define source files, constraints, device settings, and build configuration.

### `Quartus`

Intel's FPGA toolchain used here to synthesize, fit, and build the Pocket bitstream.

### `register`

In HDL, usually a named state-holding signal assigned in procedural code. Depending on context it may compile to real flip-flops or simply serve as a variable in a combinational block.

### `reset`

A signal that puts part of the design into a known starting state. Hardware designs often have carefully staged reset sequencing so clocks and memories are stable before normal operation begins.

### `scaler`

The Pocket video subsystem that receives the core's video stream and presents it on the device display or output path.

### `sequential logic`

Logic that has state and changes in relation to clock edges. Counters, state machines, and registers are common examples.

### `state machine`

A common HDL pattern where a module tracks a current state and moves between named states over time. The ROM loader and FDC data-slot adapter in this repo are good examples.

### `synchronizer`

A small hardware structure, often a chain of flip-flops, used to move signals more safely from one clock domain to another.

### `SystemVerilog`

An extension of Verilog with additional language features. This repo contains both Verilog and SystemVerilog files.

### `Verilog`

One of the main HDLs used for FPGA and ASIC design.

## Current state

The current core is a real Pocket build, not just a paper design. It already:

- builds as an Analogue Pocket openFPGA core
- boots the bundled CPC 6128 ROMs on hardware
- displays CPC video correctly enough to show the firmware screen
- loads the ROM bundle through an APF data slot
- exposes a first input path from Pocket controls to the imported CPC keyboard logic
- contains a first disk path that translates Pocket data-slot reads into the MiSTer u765 block interface

It does not yet represent a fully finished CPC core. Important gaps still include:

- audio output is currently stubbed at the Pocket output layer
- disk writes are acknowledged but not persisted
- tape support is not wired through
- savestates are not implemented
- the custom bridge register block is still minimal

Treat the code as "working skeleton plus real CPC machine pieces", not a polished end-state design.

## The mental model you need

If you come from software, the most important mindset shift is this:

- software usually describes a sequence of operations
- HDL mostly describes hardware structures that all exist at once

There is no call stack in the normal software sense. A module instance is more like an always-running component wired to other always-running components.

### Three basic HDL ideas

1. `assign` means "this wire is always driven by this expression".
2. `always @(posedge clk)` means "this logic updates on each clock edge". This is how you describe flip-flops and state machines.
3. `always @(*)` means "this is combinational logic". It reacts to input changes without storing state.

### A quick translation from software terms

| Software instinct | HDL equivalent |
| --- | --- |
| Object with fields | Module instance with internal registers and wires |
| Function output | Combinational logic result |
| Event loop tick | Clock edge |
| Mutable variable | Register updated by sequential logic |
| Shared memory | Actual RAM block or bus-connected storage |
| Background threads | Everything, all the time |

### Why clocks matter so much

On an FPGA, state changes usually happen only on a clock edge. That gives the design a stable rhythm. If two parts of the design run on different clocks, you cannot safely pass signals between them by just connecting wires and hoping for the best. You need explicit clock-domain crossing logic.

This repository uses that pattern repeatedly.

## How the Pocket core is layered

The core is easiest to understand as three layers:

```text
Analogue Pocket hardware pins / APF protocol
    -> apf_top.v
        -> core_top.sv
            -> cpc_machine_pocket.sv
                -> imported CPC machine modules
```

### 1. `src/apf_amstrad_skeleton/src/fpga/apf/apf_top.v`

This is the physical top-level for the Pocket build.

Responsibilities:

- owns the real Pocket pin list
- talks to the scaler-facing DDR video interface
- instantiates APF support blocks
- exposes the bridge bus and controller signals to `core_top`

This file is mostly platform scaffolding. It is the "Pocket shell", not the CPC machine.

### 2. `src/apf_amstrad_skeleton/src/fpga/core/core_top.sv`

This is the project's real integration layer. If you want to understand how this Amstrad core works on the Pocket, this is the most important file.

Responsibilities:

- generates the CPC clock from the Pocket's 74.25 MHz input clock
- creates reset sequencing
- synchronizes signals between clock domains
- instantiates the CPC machine wrapper
- adapts CPC video to Pocket scaler output timing
- handles ROM loading through APF data slots
- handles disk block reads through APF data slots
- maps Pocket inputs into the CPC input path

This file is where "Pocket world" meets "CPC world".

### 3. `src/apf_amstrad_skeleton/src/fpga/cpc/cpc_machine_pocket.sv`

This file is a narrow wrapper around imported MiSTer CPC logic.

Responsibilities:

- feeds the motherboard the ROM/RAM implementation it expects
- passes PS/2-style key events into the existing CPC HID block
- connects the u765 floppy controller to a Pocket-specific block transport adapter
- exports CPC-side video/debug signals back to `core_top`

This wrapper tries to avoid rewriting CPC behavior. That is an explicit project rule.

### 4. Imported CPC machine modules

The actual machine behavior is mostly in imported files such as:

- `cpc/Amstrad_motherboard.v`
- `cpc/Amstrad_MMU.v`
- `cpc/GA40010/*`
- `cpc/UM6845R.v`
- `cpc/i8255.v`
- `cpc/YM2149.sv`
- `cpc/hid.sv`
- `cpc/u765/u765.sv`
- `cpc/T80/*`

These files are the emulated hardware blocks: CPU, memory mapping, gate array, CRTC, PPI, PSG, keyboard matrix handling, and floppy controller.

## How to read the code without getting lost

Use this order:

1. `docs/REFERENCE_CORE_STEERING.md`
2. `docs/COMPONENT_MAP.md`
3. `src/apf_amstrad_skeleton/src/fpga/core/core_top.sv`
4. `src/apf_amstrad_skeleton/src/fpga/cpc/cpc_machine_pocket.sv`
5. `src/apf_amstrad_skeleton/src/fpga/cpc/cpc_ram_rom.sv`
6. `src/apf_amstrad_skeleton/src/fpga/core/pocket_dataslot_loader.sv`
7. `src/apf_amstrad_skeleton/src/fpga/core/pocket_fdc_dataslot.sv`
8. `src/apf_amstrad_skeleton/src/fpga/core/cpc_pocket_input.sv`
9. `src/apf_amstrad_skeleton/src/fpga/cpc/Amstrad_motherboard.v`

That order takes you from platform glue to machine internals.

## Repository map

The active code lives under `src/apf_amstrad_skeleton`.

### `src/apf_amstrad_skeleton/src/fpga/apf/`

Analogue's APF support files and common helpers.

Important files:

- `apf_top.v`: real Pocket top-level
- `common.v`: synchronizers and small dual-port BRAM helpers
- `io_bridge_peripheral.v`: bridge support logic used by the APF framework

### `src/apf_amstrad_skeleton/src/fpga/core/`

Project-specific Pocket integration code.

Important files:

- `core_top.sv`: main integration top
- `pocket_bridge_regs.sv`: simple custom register block
- `pocket_dataslot_loader.sv`: ROM bundle loader
- `pocket_fdc_dataslot.sv`: disk block transport adapter
- `cpc_pocket_input.sv`: Pocket input to CPC key events
- `cpc_virtual_keyboard_overlay.sv`: on-screen keyboard overlay
- `core_bridge_cmd.v`: Analogue host/target command handler
- `dpram.v`: Intel `altsyncram` wrapper used for ROM/RAM blocks

### `src/apf_amstrad_skeleton/src/fpga/cpc/`

The CPC machine and its imported subsystems.

Important files:

- `cpc_machine_pocket.sv`: project wrapper around the imported machine
- `cpc_ram_rom.sv`: local memory implementation that matches the motherboard's expectations
- `Amstrad_motherboard.v`: central CPC board wiring
- `u765/u765.sv`: floppy controller

### `src/apf_amstrad_skeleton/Cores/steve.AmstradCPC/`

Pocket metadata and packaged outputs.

Important files:

- `core.json`: core metadata
- `data.json`: APF data-slot definitions
- `input.json`: controller mapping metadata
- `video.json`: scaler metadata
- `bitstream.rbf_r`: packaged bitstream

## The boot flow

The boot sequence is the single best way to understand the architecture.

### Step 1: The Pocket configures the FPGA

The Pocket loads `bitstream.rbf_r`, which contains the compiled FPGA design.

At this point `apf_top.v` and `core_top.sv` exist as hardware.

### Step 2: `core_top.sv` comes out of its local power-on reset

`core_top.sv` contains a simple startup counter that delays `core_reset_n` until enough `clk_74a` cycles have passed. This is a common hardware pattern: wait a little while before trusting the world.

### Step 3: The CPC PLL locks

`core_top.sv` instantiates `cpc_pll` to derive the CPC system clock from `clk_74a`. It waits for the PLL lock signal and then delays again before considering that clock usable.

That gives the design two key clocks:

- `clk_74a`: Pocket/APF-facing clock domain
- `cpc_clk`: CPC machine clock domain

### Step 4: The APF host releases the core

`core_bridge_cmd.v` generates `host_reset_n`, which effectively tells the core that the Pocket host is ready for normal operation.

`core_top.sv` filters that signal so brief glitches do not immediately reset the CPC machine.

### Step 5: The ROM bundle loads through data slot `0x200`

`pocket_dataslot_loader.sv` requests data slot `0x200`, which is described in `Cores/steve.AmstradCPC/data.json` as the required `boot.rom` slot.

The host-side flow is:

1. the loader requests a chunk from the host through `core_bridge_cmd.v`
2. the Pocket host writes the returned chunk into bridge RAM at `0x60000000`
3. the loader reads that bridge RAM from the CPC clock domain
4. the loader streams bytes into `cpc_ram_rom.sv`

The loader currently expects `0xC000` bytes, or 48 KiB total.

### Step 6: `cpc_ram_rom.sv` marks the ROMs as loaded

When loading succeeds, `cpc_ram_rom.sv`:

- asserts `rom_loaded`
- marks BASIC ROM select `0x00` as present
- marks AMSDOS ROM select `0x07` as present

The bundle layout is documented in `docs/ROM_ASSET_LAYOUT.md`.

### Step 7: The CPC machine is allowed to run

`cpc_machine_pocket.sv` keeps the imported motherboard in reset until:

- the main reset is inactive
- the key-reset input is inactive
- the ROM bundle has loaded
- a small extra startup holdoff counter has expired

That last holdoff is important: the machine should not begin fetching instructions while its ROMs are only partially initialized.

## Clocks, enables, and reset

This area is worth understanding because it is where FPGA code differs most from normal software.

### Clock domains in this design

The major ones are:

- `clk_74a`: APF bridge and Pocket-facing logic
- `cpc_clk`: machine logic

Some signals originate in one domain and are consumed in the other. The code uses `synch_3` from `apf/common.v` to reduce metastability risk and to detect clean edges for single-bit signals.

### Why not run everything at one clock?

Because the Pocket platform and the CPC machine have different timing needs.

- APF bridge transactions are naturally tied to the Pocket framework clocking
- the imported CPC logic expects a machine-specific clock rhythm

Keeping these domains separate preserves the imported machine logic and keeps APF behavior local to the integration layer.

### Clock enable versus separate clock

You will see `ce_16` and `ce_pix` in addition to clocks.

A clock enable means "the main clock is still running, but only update this logic on selected cycles". That is often preferable to generating many separate clocks.

In `core_top.sv`, the CPC logic runs from `cpc_clk`, and `cpc_ce_16` pulses once every four cycles. The comment explains the intent: match the MiSTer core's 64 MHz base clock with a 16 MHz gate-array enable.

### Reset style

Different modules use different reset styles:

- some use active-low synchronous-ish startup sequencing
- some use explicit `or negedge reset_n`
- imported code often follows its original style

That mixture is normal in porting work. The important thing is to trace the actual reset source for each layer rather than expecting one universal convention.

## Memory model

The memory architecture here is "simple storage that matches what the imported motherboard expects", not "emulate every original DRAM chip cycle in detail".

### `cpc_ram_rom.sv`

This module provides:

- 128 KiB of CPC RAM
- lower OS ROM
- upper BASIC ROM
- AMSDOS ROM
- a dual-use VRAM read path for the CRTC/video side

### RAM layout

The imported motherboard exposes `mem_addr[22:0]`, and this wrapper interprets it using the MiSTer/MMU page convention:

- pages `8` through `15` are RAM
- page `0x000` is lower ROM
- page `0x100` is BASIC ROM
- page `0x107` is AMSDOS ROM

This is a good example of the project's main strategy: keep the imported addressing model and adapt local storage to it.

### Why dual-port RAM matters

The CPC machine needs the CPU side and the video side to access memory with different timing needs. `cpc_ram_rom.sv` uses two `dpram` instances for even/odd bytes so that:

- the CPU path can read/write bytes
- the video path can fetch 16-bit pairs for the CRTC/Gate Array side

`dpram.v` is a thin wrapper over Intel's `altsyncram`, which is an FPGA memory primitive.

That is another important FPGA idea: large memories are usually not inferred from "ordinary variables" the way a software programmer might imagine. They are mapped to dedicated FPGA block RAM resources.

## The CPC machine layer

`cpc_machine_pocket.sv` is the boundary between project code and imported machine behavior.

### What it adds

- ROM-loading handshake into `cpc_ram_rom.sv`
- Pocket disk transport hookup into `u765`
- fixed machine defaults like the distributor jumper value
- a reset holdoff until ROMs are ready

### What it tries not to change

- CPU timing
- Gate Array behavior
- CRTC behavior
- MMU behavior
- keyboard matrix logic already implemented in the imported CPC code

This distinction matters. When debugging, first ask whether a problem is:

- inside the imported CPC machine, or
- in the adapter layer around it

Most new development should happen in the adapter layer unless the CPC behavior itself is clearly wrong.

## Video path

The video path has two conceptual halves:

1. generate CPC pixels and syncs
2. repack them into the format the Pocket scaler wants

### CPC-side generation

Inside `Amstrad_motherboard.v`, the imported machine produces:

- color bits
- blanking
- sync
- CRTC/Gate Array timing state

`color_mix.sv` then turns the CPC color signals into 24-bit RGB.

### Pocket-side adaptation

`core_top.sv` takes the CPC RGB/sync outputs and turns them into:

- `video_rgb`
- `video_de`
- `video_hs`
- `video_vs`
- `video_rgb_clock`
- `video_rgb_clock_90`

Those are the signals `apf_top.v` pushes toward the scaler using DDR output cells.

### Why the video code looks a little strange

The Pocket scaler interface is not the same thing as "native CPC video timing". So `core_top.sv` contains adapter logic that:

- derives an APF-facing pixel cadence
- detects sync edges from the CPC outputs
- delays/re-shapes those signals for the Pocket output side
- overlays a virtual keyboard on top of CPC RGB when enabled

If you are tracing a display bug, check whether it is:

- wrong inside the CPC machine
- wrong in `color_mix.sv`
- wrong in the Pocket output adaptation in `core_top.sv`

### Fallback display mode

Before the ROM bundle finishes loading, `core_top.sv` can still generate a simple visible frame instead of relying on real CPC video. That lets the build show a defined screen state during early startup and loader error conditions.

## Input path

The input path is intentionally pragmatic.

The imported CPC HID logic already understands MiSTer-style PS/2 key events, so the Pocket integration does not try to rewrite the CPC keyboard matrix handling from scratch.

### Controller metadata

`Cores/steve.AmstradCPC/input.json` tells the Pocket UI how to name and expose the controls. For example:

- `A` is Enter
- `B` is Space
- `X` is Delete
- `Y` is Escape
- `L` is Shift
- `R` is Ctrl
- Select toggles the virtual keyboard
- Start resets the machine

### Runtime mapping

`cpc_pocket_input.sv` converts Pocket button transitions and dock keyboard HID reports into the 11-bit PS/2 event format used by the imported CPC HID path:

`{toggle, pressed, extended, scan_code}`

This is a good local example of an adapter module:

- Pocket controls in
- legacy CPC-compatible key events out

### Virtual keyboard

The virtual keyboard has two pieces:

- `cpc_pocket_input.sv` controls selection, pages, and key event generation
- `cpc_virtual_keyboard_overlay.sv` draws the overlay into the video stream

This is not a software UI toolkit. The overlay is literally generated by hardware logic that tracks pixel coordinates and conditionally replaces RGB values.

## Disk and media path

The floppy path is another translation layer between Pocket concepts and MiSTer/CPC concepts.

### What the CPC side expects

The imported `u765` controller does not know about Analogue Pocket data slots. It expects a block-device-like interface:

- block address via `sd_lba`
- read/write request via `sd_rd` / `sd_wr`
- completion via `sd_ack`
- a 512-byte sector buffer interface

### What the Pocket side provides

The Pocket host provides file/data-slot operations through the APF bridge command system.

### What `pocket_fdc_dataslot.sv` does

This module translates between the two models:

1. watch for `u765` block read requests
2. turn them into APF target data-slot reads
3. ask the host to DMA a 512-byte block into bridge RAM at `0x70000000`
4. stream those bytes into the `u765` sector buffer
5. assert `sd_ack`

At the moment, writes are effectively fake-completed:

- the module acknowledges them so the state machine does not hang
- it does not persist modified sectors back to the Pocket host

That makes the current floppy path read-only in practice.

### Data-slot IDs for media

`data.json` currently defines:

- `0x200`: required ROM bundle
- `1`: Drive A
- `2`: Drive B
- `3`: Tape

Only the ROM bundle and early disk path are meaningfully wired today.

## APF bridge and command system

There are two related but different things in this repository:

1. Analogue's generic APF host/target command mechanism
2. this project's own simple register block

### `core_bridge_cmd.v`

This is Analogue's command handler. It is mapped to bridge addresses under `0xF8xxxxxx`.

In this project it mainly serves as:

- the framework-facing reset/status block
- the data-slot command interface used by the ROM loader and FDC adapter
- the source of `dataslot_update` notifications when media is mounted

This file is generic, fairly low-level, and not CPC-specific.

### `pocket_bridge_regs.sv`

This is the project's small custom register block. It exposes some simple state at low addresses such as:

- control
- model config
- AV config
- media flags
- loader bookkeeping

Right now it is intentionally thin. The real heavy lifting still happens through the APF command/data-slot path, not through an elaborate custom register protocol.

## Suggested debugging strategy

When something breaks, first classify the bug by layer.

### If the core does not boot at all

Check:

- `ap_core.qsf` includes the right source files
- `core_top.sv` reset and PLL-lock sequencing
- `pocket_dataslot_loader.sv` state machine
- `cpc_ram_rom.sv` `rom_loaded`

### If the ROM loads but the machine does not execute correctly

Check:

- `cpc_machine_pocket.sv` reset gating
- `Amstrad_motherboard.v`
- `Amstrad_MMU.v`
- whether the ROM bundle layout matches `docs/ROM_ASSET_LAYOUT.md`

### If video is wrong

Check:

- `color_mix.sv` for CPC color conversion
- CPC sync and blanking signals from `cpc_machine_pocket.sv`
- Pocket adaptation logic in `core_top.sv`
- `Cores/steve.AmstradCPC/video.json`

### If keyboard input is wrong

Check:

- `input.json`
- `cpc_pocket_input.sv`
- imported `hid.sv` behavior

### If disk access is wrong

Check:

- `pocket_fdc_dataslot.sv`
- `core_bridge_cmd.v` target data-slot signaling
- `u765/u765.sv`

## Build and packaging flow

The source-of-truth Quartus project file is:

- `src/apf_amstrad_skeleton/src/fpga/ap_core.qsf`

That file lists the active HDL sources and project assignments for the Pocket build.

### Useful commands

From the repository root:

```bash
make check
make build-skeleton
make install-pocket
```

### What `make check` does

It runs:

- `scripts/check_expected_files.py`
- `scripts/check_skeleton.py`

`check_skeleton.py` is useful because it validates more than syntax:

- required files exist
- JSON metadata parses
- the active QSF source list only contains approved files
- obvious leftover ZX Spectrum references are rejected
- the packaged Pocket bitstream looks like a bit-reversed `_rbf_r`

### What `make build-skeleton` does

It runs the Docker-based Quartus build script:

- `scripts/build_skeleton_docker.sh`

The build emits a raw Quartus `.rbf`, then converts it into Pocket format as `bitstream.rbf_r` by reversing the bit order in each byte.

## A few Verilog details that will help you read this repo

### `wire` versus `reg`

In older Verilog style:

- `wire` usually means a continuously driven signal
- `reg` means a variable assigned inside an `always` block

`reg` does not automatically mean "hardware register". In an `always @(*)` block it can still describe combinational logic.

### Blocking versus non-blocking assignment

Inside clocked logic you will usually see non-blocking assignments:

```verilog
counter <= counter + 1'd1;
```

That models state updates happening together at the clock edge. If you come from software, do not read it as "execute immediately and then continue". It describes next-state behavior.

### State machines are common

`pocket_dataslot_loader.sv` and `pocket_fdc_dataslot.sv` are classic finite-state machines. That is one of the most common HDL patterns:

- keep a `state` register
- move between named states on each clock edge
- drive outputs according to the current state

If a module feels procedural, it is often best understood as a state machine.

## What is platform-specific versus reusable

### Mostly Pocket-specific

- `apf_top.v`
- `core_top.sv`
- `pocket_dataslot_loader.sv`
- `pocket_fdc_dataslot.sv`
- `pocket_bridge_regs.sv`
- metadata JSON files under `Cores/` and `Platforms/`

### Mostly CPC/MiSTer-derived

- `Amstrad_motherboard.v`
- `Amstrad_MMU.v`
- `GA40010/*`
- `UM6845R.v`
- `i8255.v`
- `YM2149.sv`
- `hid.sv`
- `u765/u765.sv`
- `T80/*`

### Hybrid boundary code

- `cpc_machine_pocket.sv`
- `cpc_ram_rom.sv`
- `cpc_pocket_input.sv`

These are the files where you should expect the most PocketCPC-specific design decisions.

## Good next files to study

If you want to keep learning by reading code, these are the best next targets.

### For APF/Pocket integration

- `src/apf_amstrad_skeleton/src/fpga/core/core_top.sv`
- `src/apf_amstrad_skeleton/src/fpga/core/pocket_dataslot_loader.sv`
- `src/apf_amstrad_skeleton/src/fpga/core/pocket_fdc_dataslot.sv`
- `src/apf_amstrad_skeleton/src/fpga/core/core_bridge_cmd.v`

### For CPC machine behavior

- `src/apf_amstrad_skeleton/src/fpga/cpc/cpc_machine_pocket.sv`
- `src/apf_amstrad_skeleton/src/fpga/cpc/Amstrad_motherboard.v`
- `src/apf_amstrad_skeleton/src/fpga/cpc/Amstrad_MMU.v`
- `src/apf_amstrad_skeleton/src/fpga/cpc/GA40010/ga40010.sv`
- `src/apf_amstrad_skeleton/src/fpga/cpc/UM6845R.v`

### For practical FPGA patterns used here

- `src/apf_amstrad_skeleton/src/fpga/apf/common.v`
- `src/apf_amstrad_skeleton/src/fpga/core/dpram.v`

## Summary

The simplest correct mental model for this repository is:

- the Pocket shell is generic platform code
- `core_top.sv` is the adapter layer
- the imported MiSTer CPC logic is the machine
- most new work should preserve the machine and modify the adapter

If you keep that split in mind, the codebase becomes much easier to navigate.
