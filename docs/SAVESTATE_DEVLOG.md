# Savestate Devlog

Last updated: 2026-07-28

This document records what has been tried for Pocket savestates, what failed,
and which constraints now look non-negotiable. The goal is to stop future work
from rediscovering the same dead ends.

## Scope

This log is specifically about Pocket `Memories` savestates, not `.sna`
snapshot files. `.sna` remains useful as a CPC-native format and as a source
for some machine-state packing ideas, but Pocket savestates have different host
integration rules and different failure modes.

## What The Pocket Actually Expects

The most important documented APF behavior is:

- `Savestate: Start/Query` (`0x00A0`) reports whether save is supported, plus
  the address and size of the blob once it is ready.
- `Savestate: Load/Query` (`0x00A4`) reports whether load is supported, plus
  the address and maximum size of the blob the Pocket should write.
- During runtime, Pocket queries first, then requests the operation, polls for
  completion, and only then copies the data out or in.

References:

- [Analogue Host/Target Commands](https://www.analogue.co/developer/docs/host-target-commands)
- [Analogue Core Boot Process](https://www.analogue.co/developer/docs/core-boot-process)
- Local implementation entry point: [src/fpga/core/core_bridge_cmd.v](/Users/steve/code/github.com/stilvoid/PocketCPC/src/fpga/core/core_bridge_cmd.v:483)

One local APF detail matters a lot for any non-BRAM backing store:

- `io_bridge_peripheral.v` states that bridge reads are buffered by one word.
- The bridge should always return the current bus word and use the read strobe
  to kick off the next fetch.

Reference:

- [src/fpga/apf/io_bridge_peripheral.v](/Users/steve/code/github.com/stilvoid/PocketCPC/src/fpga/apf/io_bridge_peripheral.v:37)

Implication: an external-memory-backed savestate window cannot be treated like a
simple synchronous block RAM port. It needs read-ahead or equivalent behavior.

## Core-Specific State We Need To Preserve

The current Pocket savestate payload shape is aimed at:

- 128 KiB CPC RAM
- CPU register block
- CRTC registers
- Gate Array palette/config state
- RAM/ROM config
- PPI state
- PSG registers
- selected machine model
- whether the optional custom upper ROM is active

The current save/load plumbing still treats some areas as incomplete or unsafe:

- save is rejected during active disk or tape activity
- tape runtime position is not preserved yet
- in-flight FDC internal state may still need a broader audit
- any adapter-local latches outside the imported CPC machine must be reviewed

## What We Started With

There was already savestate code in the tree from an older attempt, but it
predated the current core structure and was explicitly treated as untrusted. It
was not safe to use as a design reference.

Decision:

- do not preserve the old implementation just because it exists
- re-derive the solution from documented Pocket behavior plus the now-stable
  CPC core structure

## Experiments And Outcomes

### 1. Early revive-and-debug pass

Symptoms seen on hardware across repeated tests:

- Pocket reported `Savestate not supported`
- save appeared to complete, but load failed
- failed loads sometimes reset the CPC, sometimes froze it
- some builds caused Pocket to crash while loading the core itself
- save and load latency varied from immediate failure to delayed failure

What we did:

- added progressively richer debug registers under `pocket_bridge_regs.sv`
- captured device logs and saved-state files from the Pocket
- traced host writes and load-word parsing state

Useful local references:

- [src/fpga/core/pocket_bridge_regs.sv](/Users/steve/code/github.com/stilvoid/PocketCPC/src/fpga/core/pocket_bridge_regs.sv:112)
- [docs/DEVELOPER_GUIDE.md](/Users/steve/code/github.com/stilvoid/PocketCPC/docs/DEVELOPER_GUIDE.md:332)

Conclusion:

- debugging was necessary, but the implementation path itself remained too
  fragile
- repeated failures suggested the architecture, not just a small bug, needed to
  change

### 2. Direct/live streaming style designs

The project tried variants that effectively streamed state across the APF
boundary rather than staging a full Pocket-visible blob in an external store.

Why this was a poor fit:

- too many cross-domain corner cases
- difficult to reason about against the Pocket save/load handshake
- hard to debug because host timing, SRAM timing, and CPC timing all interacted
  at once

Decision:

- do not return to a no-staging or effectively-live-streaming savestate design

### 3. Full on-chip BRAM mirror of the APF savestate window

This was the later “make it simpler for the Pocket side” attempt: create a
contiguous APF-visible window backed by a dual-clock internal RAM, and let the
CPC side serialize into and out of that mirror.

Why it looked attractive:

- simple Pocket-facing address map
- easy bridge reads and writes
- clearer separation between APF access and CPC packing logic

Why it failed:

- the full Pocket savestate image is too large to duplicate in Cyclone V M10Ks
- fitter failed, so this route is not merely suboptimal; it is infeasible on
  this device

Observed fitter data from the failed build on 2026-07-20:

- `Total block memory bits : 3,425,472 / 3,153,920 (109%)`
- `M10K blocks : 423 / 308 (137%)`
- the savestate buffer alone consumed `1,049,536` bits, about `130` M10Ks

References:

- [build/quartus/output_files/ap_core.fit.summary](/Users/steve/code/github.com/stilvoid/PocketCPC/build/quartus/output_files/ap_core.fit.summary:1)
- [build/quartus/output_files/ap_core.fit.rpt](/Users/steve/code/github.com/stilvoid/PocketCPC/build/quartus/output_files/ap_core.fit.rpt:3305)

Decision:

- treat the full-BRAM-buffer route as closed
- do not revisit it unless the savestate size shrinks dramatically or the
  target device changes

## What We Learned From Reference Patterns

Reference-core guidance still matters here, even though no local reference core
gave us a drop-in Pocket savestate solution.

Patterns that still held up:

- keep APF/Pocket behavior local to adapter logic, not scattered through the
  imported CPC machine
- preserve MiSTer-derived machine-state packing and restore semantics where
  practical
- use the ZX Pocket/APF wiring style for host-facing command handling and clock
  separation

References:

- [docs/COMPONENT_MAP.md](/Users/steve/code/github.com/stilvoid/PocketCPC/docs/COMPONENT_MAP.md:31)
- [src/fpga/core/core_top.sv](/Users/steve/code/github.com/stilvoid/PocketCPC/src/fpga/core/core_top.sv:1)

Important absence:

- no trusted local reference core was found that justified mirroring a full
  Pocket savestate blob in BRAM

That absence should have been treated as a warning earlier.

## Load-Path Validation Against Analogue Docs And Working Cores

Two references matter here.

Analogue's own runtime description says savestate load happens in this order:

1. Pocket queries support and the destination address.
2. Pocket copies the savestate data into that address.
3. Pocket calls `0x00A4` again with "Request load" set.
4. Pocket polls until the core reports completion.

Reference:

- [Analogue Core Boot Process](https://www.analogue.co/developer/docs/core-boot-process)
- [Analogue Host/Target Commands](https://www.analogue.co/developer/docs/host-target-commands)

That ordering means a core should treat the blob at the advertised bridge
address as authoritative when `savestate_load` is asserted. It should not need
an additional post-request "blob ready" event if the documentation is being
followed.

A working open-source Pocket core with Memories support reinforces that model:

- `budude2/openfpga-GBC`
- local inspected file:
  [save_state_controller.sv](/Users/steve/code/github.com/stilvoid/PocketCPC/upstreams/openfpga-GBC/src/gb/save_state_controller.sv:267)

That controller's load path explicitly comments:

- data is already copied into its savestate manager before APF load begins

Design consequence:

- for PocketCPC, the simplest viable load path is to begin reading the staged
  SRAM blob immediately on `savestate_load`

## Current Working Hypothesis

The latest hardware behavior narrowed the likely fault domain:

- `.sna` loading is back to normal
- disk loading is back to normal
- Pocket savestate load still fails immediately
- saved `.sta` files still do not contain the expected `PCS1` header anywhere

That combination makes a restore-only bug unlikely. Both the broken operations
still depend on the same bridge-clock-domain SRAM readback path:

1. Pocket save export reads the staged blob back out through that path.
2. Pocket load validation reads header words `0` and `1` back through that
   path before applying state.

So the next build-worthy iteration is to make the SRAM read side more
conservative before revisiting higher-level save/load logic again.

## 2026-07-21 Iteration: Conservative SRAM Read Timing

The bridge-domain SRAM state machine originally switched address and sampled the
16-bit SRAM bus on the very next bridge clock for both low and high halfwords.

That is an optimistic assumption for an external async SRAM path, especially
when both halfword selects and address lines are changing between samples.

Change made:

- add an extra wait cycle after asserting each halfword read address before
  sampling `sram_din`

Why this is build-worthy:

- it targets the one bridge readback path shared by the two remaining failures
- it is simpler than inventing more savestate protocol machinery
- it follows the “do the least clever thing that can work” rule: allow more
  settling time on the external memory interface before sampling data

## 2026-07-27 Finding: Save Export Was Dropping The First Snapshot Word

The latest `.sta` inspections finally exposed a concrete export-side symptom:

- the embedded CPC payload did not begin with `MV -`
- it began with ` SNA`
- the words after that were also displaced or malformed

That matters because it is exactly the failure pattern expected when the Pocket
bridge sees stale bus data for the first read and the core only reacts once the
read strobe arrives.

Why this fits the documentation:

- `io_bridge_peripheral.v` explicitly says bridge reads are buffered by one word
- the core must already have the current word on the bus before the bridge
  asserts its read pulse for fetching the next word

The previous local design violated the spirit of that rule in two ways:

- it relied too heavily on `bridge_rd` to decide what the current exported word
  should be
- it depended on direct dual-port RAM reads for early savestate words instead of
  explicitly seeding the bridge with known-good data

Current direction:

- preload exported snapshot words `0` and `1` into bridge-domain registers as
  soon as save completion is acknowledged
- walk the header region from those bridge-domain registers so the first Pocket
  reads do not depend on late read-side fetches
- keep using the staged external-memory blob for the bulk payload, but stop
  assuming the bridge can “pull” the first words into place on demand

Why this is build-worthy:

- it is a direct response to an observed file-format symptom, not a speculative
  timing guess
- it matches the documented APF one-word buffered read model more closely than
  the previous export path

## 2026-07-27 Iteration: Unregistered Bridge-Side Front Buffer

Repeated `.sta` inspection showed the first exported payload words were still
wrong even after the PSRAM read path and bridge stepping logic were tightened.
The most consistent symptom was a missing or shifted first word at the start of
the Pocket-visible savestate blob.

That pointed back to a simpler issue:

- the Pocket bridge reads the current word while its read strobe is used to
  trigger the next fetch
- a fully synchronous dual-clock BRAM front buffer still imposes a one-cycle
  read latency on the bridge-facing side
- that is a poor match for the documented APF bridge behavior

Change made:

- replace the tiny `savestate_front_buffer` implementation with a dual-clock
  `altsyncram` wrapper that keeps port A, the bridge-facing port, unregistered
- keep the CPC-facing port clocked, because Quartus requires the port B address
  and write-control registers in this configuration

Why this is a meaningful iteration:

- it changes the first-word export path itself, not just surrounding handshake
  logic
- it keeps the staged external-memory design intact
- it follows the documented APF bridge model more closely than the registered
  BRAM mirror did

## 2026-07-27 Iteration: Direct Header Export From Latched Save State

Later log inspection narrowed the failure further:

- the `SSLE` debug words come from the core's own save-time PSRAM verify path,
  not from Pocket reloading the file
- those words were already wrong before Pocket exported the `.sta`
- the Pocket-visible `.sta` also consistently missed the leading `MV -` word,
  which is enough to cause an immediate load rejection

That split the problem into two layers:

1. the staged save image in PSRAM is still not fully trustworthy
2. the immediate user-visible load failure is caused by a broken snapshot
   header at export time

Change made:

- latch the full CPC snapshot header source state during `SAVE_SETTLE`
- use those latched values for `snapshot_header_word(...)` during save
- on Pocket bridge reads, serve header words `0..63` directly from the latched
  header state once save completion is reported, instead of relying on the
  staged memory copy for that region

Why this is build-worthy:

- it targets the exact missing-magic failure Pocket is reacting to
- it avoids asking the same flaky staging path to prove its own header
  correctness
- it leaves the larger PSRAM staging bug isolated for follow-up if load gets
  past header validation

Outcome:

- immediate savestate-load failure still reproduced

Revised conclusion:

- the SRAM bus timing may still matter, but it is no longer the best primary
  suspect
- the stronger structural weakness is the CPC-to-bridge mailbox itself

## 2026-07-21 Iteration: Replace Toggle Mailbox With Dual-Clock FIFOs

The original external-SRAM staging controller passed request payloads and
response payloads across clock domains using:

- a separate edge toggle
- independent multi-bit `synch_3` crossings for write flag, address, and data

That is not a coherent transport for 32-bit or 49-bit payloads. Even if the
toggle edge arrives cleanly, the synchronized payload bits can still represent a
torn mix of old and new values at the receiving clock edge.

Why this matters here:

- save-side SRAM writes from the CPC domain can land at the wrong address or
  with corrupted data, which would explain malformed `.sta` payloads
- load-side SRAM reads returned to the CPC domain can also be torn, which would
  explain immediate header validation failure

Change made:

- replace the toggle-plus-synchronizer mailbox with `sync_fifo` dual-clock FIFOs
  for:
  - CPC-domain SRAM requests into the bridge domain
  - bridge-domain SRAM responses back into the CPC domain

Why this is build-worthy:

- it directly addresses a real CDC design flaw instead of another timing guess
- it matches the simplest robust pattern already available in the repo
- it can explain both the bad exported savestate image and the immediate load
  rejection with one cause

Outcome:

- immediate savestate-load failure still reproduced
- latest saved `.sta` payload still had no `PCS1` header anywhere in the
  Pocket-visible blob

Revised conclusion:

- bridge read timing may still matter at the margins, but the remaining common
  dependency is "correctly write 32-bit words into external SRAM"

## 2026-07-21 Iteration: Conservative External SRAM Writes

The external SRAM write sequencer was still optimistic.

For both low and high 16-bit halfwords it previously:

1. changed address
2. changed data
3. enabled output drive
4. asserted `WE`

all in the same bridge-clock cycle.

That is a weak assumption for an async SRAM interface. If the device needs
address and data setup time before the write pulse, then some writes can land
with partial or incorrect values.

Why this matters here:

- save staging writes header and RAM data into SRAM before the Pocket reads the
  blob out
- load import writes the Pocket-provided blob into that same SRAM before the CPC
  domain validates and restores it

So a broken write path alone can explain:

- malformed saved `.sta` files
- immediate savestate-load header rejection

Change made:

- add explicit setup cycles before asserting `WE` for both the low and high
  16-bit halfword writes
- keep address, data, and bus drive stable for a full bridge-clock cycle before
  each write pulse

Why this is build-worthy:

- it targets the only remaining hardware path shared by both failures
- it is simpler and more defensible than adding more savestate-side protocol
  machinery
- it aligns the implementation better with a conservative async-SRAM timing
  model

Outcome:

- the payload changed, so the write-side timing change did affect staged data
- savestate load still failed immediately
- the exported `.sta` payload still contained no `PCS1` header anywhere

Next debug direction:

- capture staged word `0` and word `1` from two viewpoints:
  - CPC-domain readback from SRAM after save completion
  - bridge-domain primed export words after save completion

That split is intended to answer one question cleanly:

- are the first savestate words already wrong in SRAM, or do they become wrong
  only on the Pocket-facing export path?
- validate header and version first
- fail fast with `load_err` if those first words are wrong
- only keep `load_busy` high while actual restore work is underway

## 2026-07-22 Iteration: Retire The Small SRAM Backend

The dedicated `sram_*` device looked attractive because it was separate from
the working CPC RAM implementation and seemed simple to claim for savestate
staging.

In practice, it forced PocketCPC onto a fully custom bridge-domain memory
controller and that became the least trustworthy part of the design.

Decision:

- retire the custom small-SRAM backend for savestate staging
- move staging onto the Pocket `cram*` PSRAM interface instead
- copy the proven `psram.sv` controller shape already used by the imported
  Pocket reference cores

Why this is the simpler path:

- the Pocket PSRAM interface already has a known-good controller in local
  references
- PSRAM capacity is comfortably larger than the savestate blob
- it preserves the earlier architectural decision not to move CPC RAM itself
- it removes the weakest custom hardware block from the savestate path

## Current Direction

The current direction is:

1. Keep the full savestate blob in external PSRAM.
2. Keep CPC RAM where it already works. Do not move CPC RAM just to make
   savestates easier.
3. Let the bridge clock domain own the physical PSRAM pins.
4. Let the CPC clock domain access the staged blob through a narrow mailbox or
   handshake path rather than through a second full-size copy.
5. Preserve aggressive debug visibility while this is still unstable.

## 2026-07-22 Iteration: Retire The `PCS1` Payload

The custom `PCS1` savestate payload turned out to be the wrong abstraction.

Why:

- Pocket only requires a core-defined blob at a bridge address. It does not
  require a custom snapshot format.
- PocketCPC already has working `.sna` snapshot load semantics.
- The custom payload duplicated the CPC state model, packing logic, and restore
  logic instead of reusing the known-good snapshot format.

Decision:

- stop using the custom `PCS1` payload for Pocket Memories
- stage a real CPC `.sna`-compatible snapshot image in PSRAM instead
- keep the Pocket handshake and PSRAM bridge path, but make the staged bytes
  follow the same snapshot layout already used by the existing `.sna` loader

Why this is the simpler path:

- one CPC snapshot model instead of two
- save-side packing now matches the existing `.sna` snapshot saver byte layout
- load-side restore now targets the same `sna_*` register bundle and memory
  interpretation that standard snapshot loading already uses
- it makes future debugging about Pocket transport and restore timing, not
  about a second invented file format

Why this is the best current path:

- it keeps the required full image off-chip
- it matches the user-visible Pocket model better than live streaming
- it avoids spending impossible amounts of BRAM
- it keeps the change local to the Pocket adapter boundary

## Active Risks

- the PSRAM-backed bridge view must satisfy the APF one-word-buffered read
  behavior from `io_bridge_peripheral.v`
- the direct bridge-window implementation is still not trustworthy unless it
  buffers host traffic explicitly; the latest code review found that bridge
  writes were only accepted while the PSRAM state machine happened to be idle,
  which means Pocket load traffic could be dropped under burst conditions
- load ordering still has to be validated carefully against snapshot restore
  timing and reset release
- bridge-domain `load_busy` synchronization cannot be used as a proxy for
  “the host has started or finished writing the blob”; hardware testing showed
  a real timeout case where the Pocket kept polling until failure because the
  core waited for a completion condition derived from a delayed `load_busy`
  edge instead of from the actual blob write addresses
- current Pocket host logs suggest the blob can already be staged before the
  core sees the explicit load request: the log shows the `.sta` being opened
  and byte count reported before the `0x00A4` request that asks the core to
  begin loading, so any design that only waits for a post-request “blob ready”
  pulse is at risk of missing the event entirely
- the latest hardware log on 2026-07-27 still shows an immediate load reject
  with a malformed staged header:
  - bridge-side debug saw word `0` as `0x4D56202D` (`"MV -"`)
  - bridge-side debug saw word `1` as `0x00008040` instead of `" SNA"`
  - this narrows the current fault to save staging or early bridge export, not
    to the later CPC restore/apply phase
- the exact “safe to save” and “safe to load” gates may still need refinement
- adapter-local state outside the imported CPC machine may still be missing from
  the blob

## 2026-07-27 Iteration: Buffer Bridge Traffic, Then Re-test Header Word 1

Fresh logs from `stilvoid.PocketCPC_20260727_160655.txt` finally separated two
different problems that had previously been conflated.

What the log showed on the failing load:

- Pocket still failed the load immediately with result `0x0003`
- debug event `SSLE` fired again
- bridge-side primed save word `0` was now correct:
  `0x4D56202D` (`"MV -"`)
- bridge-side primed save word `1` was still wrong:
  `0x00008040`

Why that matters:

- the failure still occurs before any meaningful restore of CPC RAM or
  registers
- the first staged word being correct means the save blob is no longer
  completely broken
- the second staged word being wrong means the current bug is much narrower:
  either the save-side header staging corrupts word `1`, or the Pocket-facing
  PSRAM export path fails on the first back-to-back word transition

At the same time, code review of the bridge path found a separate structural
bug:

- bridge writes from Pocket load traffic were only handled when the PSRAM state
  machine was idle
- there was no queue for burst writes
- under load, this could silently drop host-provided savestate words

Decision:

- keep the PSRAM-backed approach
- stop trusting the direct, no-queue bridge window
- add explicit buffering for bridge writes
- make bridge-side save export advance on real read strobes rather than on
  free-running address observation
- add a conservative inter-transaction gap on the PSRAM wrapper side while the
  second-header-word fault is still under investigation

Follow-up hardware result from the next run on 2026-07-27:

- load still failed immediately, but the CPC no longer reset afterward
- debug now showed:
  - save readback word `0` = `0x4D56202D` (`"MV -"`)
  - save readback word `1` = `0x803F0010`
  - bridge prime word `0` = `0x20534E41` (`" SNA"`)
  - bridge prime word `1` = `0x04003F00`

Interpretation:

- the very first staged word is now stable
- the earliest remaining corruption is concentrated in the first
  immediately-following full-word transactions
- that makes "insufficient gap between completed PSRAM transactions" a stronger
  current hypothesis than a generic header-packing bug

Next iteration:

- keep the buffered bridge write path
- extend the PSRAM inter-transaction cooldown from a single bridge clock to a
  small fixed multi-cycle gap before the next read or write request is issued

## 2026-07-27 Harness: Compare `SSLE` Save Words Against A Known-Good `.sna`

At this point the project needed a tighter feedback loop than "build, test on
hardware, and eyeball a few debug words in the log."

Decision:

- use a known-good `.sna` fixture as the reference state
- compare the first staged savestate words against the first words of that
  `.sna`
- make the failure event burst prioritize staged save words before secondary
  bridge or status data

Implementation:

- the save path now retains staged readback words `0..3`
- the `SSLE` target-event burst now emits those four words immediately after the
  marker
- `scripts/compare_sna_debug.py` compares the most recent `SSLE` burst in a
  Pocket log against a fixture `.sna`

Why this is the right harness first:

- it directly tests the part of the pipeline that is still failing
- it avoids adding another moving part such as a CPC-side setup program
- it keeps `.sna` as the ground truth because standard snapshot loading already
  works in the core

## Rules For Future Savestate Work

- Read this file before changing savestate code.
- Do not propose a full-BRAM mirror again unless there is a quantified device
  resource argument showing it fits.
- Do not remove debug instrumentation until save and load both pass repeated
  hardware cycles.
- Do not assume a load failure is a single bug when the architecture has
  already failed once at the design level.
- Prefer completion conditions derived from the actual staged blob contents or
  write addresses, not from inferred timing around Pocket command status bits.
- Change one axis at a time and record the observed hardware result after each
  build the human tests.

## 2026-07-27 Iteration: Replace Implicit CDC Mailboxes With Explicit FIFO Pops

Fresh evidence from the `.sna` comparison harness showed that the staged save
blob was already wrong before restore logic touched it:

- the first few staged words captured in the `SSLE` failure burst did not match
  the first words of the known-good `.sna`
- the mismatch pattern was not a simple one-word shift or byte-swap
- some words were duplicated while adjacent words were wrong or zero

That made "restore logic bug" a weaker hypothesis than "request/response words
are being misordered or duplicated before they even land in PSRAM."

Cross-check against reference cores:

- Analogue's documented contract remains simple: Pocket writes the blob to the
  advertised address first, then asserts `savestate_load`
- the local GBC reference still treats the blob as already staged when load
  begins and uses explicit edge-driven state sequencing rather than an inferred
  mailbox protocol
- the July 2026 Genesis core release likewise keeps the APF handshake simple
  and is conservative about request edges, busy/ok/error flags, and staging
  completion

Problem found in local implementation:

- the helper `sync_fifo.sv` continuously re-armed reads whenever the FIFO was
  non-empty, even while a previous pop was still in flight
- that behavior is tolerable for lossy or stream-like crossings, but it is not
  a good fit for ordered one-request / one-response mailbox traffic
- our savestate controller was using that helper for the CPC-domain SRAM
  request queue and the bridge-domain response queue

Decision:

- keep the PSRAM-backed staging design
- keep the Pocket save/load handshake
- replace the savestate controller's implicit mailbox crossing with explicit
  `dcfifo` instances plus one-pop-at-a-time consumer state machines in each
  domain

Why this is worth a build:

- it directly targets the point where the new harness says corruption first
  appears
- it is narrower and more falsifiable than another restore-side tweak
- if staged words now match the `.sna` fixture but load still fails, we will
  have cleanly separated "blob integrity" from "blob application"

Follow-up hardware result from the next run on 2026-07-27:

- save still completed
- load still failed immediately without resetting the CPC
- the `SSLE` comparison signature remained:
  - expected word `0` = `0x4D56202D`, actual `0x00000000`
  - expected word `1` = `0x20534E41`, actual `0x20534E41`

New forensic check:

- the saved Pocket `.sta` itself was inspected on the mounted device
- its container header appears to place the core payload around offset
  `0x250..0x254`
- at that payload boundary, the file begins with a zero word and then
  `0x20534E41` (`" SNA"`)
- the required first header word `0x4D56202D` (`"MV -"`) does not appear
  anywhere in the saved `.sta`

Interpretation:

- this is stronger evidence than the earlier `SSLE` burst alone
- the save/export path is still losing the first 32-bit payload word before the
  file is written
- the failure is now best explained as a save-export start race, not as a
  general snapshot pack/unpack failure

Decision for the next iteration:

- keep the PSRAM staging and `.sna` payload shape
- make the save-export "ready" signal more conservative
- do not let Pocket start reading the staged blob until the bridge-domain prime
  words have been stable for at least one full bridge clock after prefetch

Validation:

- `make validate` succeeded on 2026-07-27 after this change

## 2026-07-27 Iteration: Treat APF Reads As One-Word-Delayed Requests

Re-reading the APF bridge implementation changed the current diagnosis.

The important timing detail is not just that reads are "buffered by one word";
in `io_bridge_peripheral.v`, the current `pmp_rd_data` value is latched for
transmission before `pmp_rd` is pulsed to the core. That makes `pmp_rd` the
core's request to prepare the value for a subsequent bridge read, not the point
where the core can still affect the data currently being returned.

Why the previous PocketCPC export design was wrong:

- it preloaded words `0` and `1` when save completion was reported
- when the first savestate-window read strobe arrived, it advanced the exported
  word to word `1`
- hardware then saved a blob whose apparent payload began with `0x20534E41`
  (`" SNA"`) and had no `0x4D56202D` (`"MV -"`) anywhere

This matches a one-word-too-eager exporter: the Pocket/APF side performs the
read transaction that gives the core a chance to prepare word `0`, but the core
had already advanced to word `1` by the time the host stored payload data.

Change made:

- remove the bridge-domain current/next export cache
- make `bridge_rd_data` a single registered export word
- on each savestate-window `bridge_rd` strobe, prepare exactly the requested
  word into that register for the next APF transfer
- continue serving `.sna` header words directly from the latched snapshot
  header state
- continue serving RAM payload words from the staged PSRAM blob

What this keeps intact:

- `.sna` remains the core-defined Pocket savestate payload format
- the full payload remains staged in external PSRAM
- CPC RAM remains in its existing working storage
- the working `.sna` dataslot loader remains untouched

Expected next hardware proof:

- saving should produce a `.sta` whose core payload contains `MV -`
- if load still fails, the `SSLE` debug burst should show whether the staged
  header is now correct and whether the remaining bug is in load/apply rather
  than save/export

Why this is build-worthy:

- it directly explains the specific missing-first-word symptom
- it aligns with the documented/APF-implemented bridge buffering model
- it follows the GBC reference pattern more closely: use the read strobe to
  advance/prep the next APF-visible word instead of trying to maintain a
  random-access cache that changes before the host has consumed the current
  value

Validation:

- `make validate` succeeded on 2026-07-27 after this change with 0 errors and
  10 warnings

## 2026-07-28 Direction Change: Use SNA v3 Timing State

Hardware result after snapshot loading was restored:

- ordinary `.sna` snapshot loading worked again
- manual Memories still worked
- sleep/wake restored, but wake could take roughly ten seconds
- one wake produced a coherent but misframed Dizzy Kwik Snax screen
- another wake restored Alien 8 to a visible screen but left the CPC
  unresponsive with a continuous beep

Interpretation:

- the latest sleep state parsed as a valid SNA payload, so the blob is not
  obviously corrupt
- the misframed Dizzy screenshot points at CRTC/video phase rather than random
  RAM corruption
- SNA v2 already stores the selected CRTC register and CRTC register values,
  which PocketCPC was already saving and loading
- SNA v3 is the documented CPC snapshot format that adds internal CRTC timing
  counters and flags: horizontal character counter, character-line counter,
  raster-line counter, vertical-adjust counter, hsync/vsync width counters,
  CRTC state flags, CRTC type, and GA interrupt state

Change made:

- hardware-created PocketCPC savestates now emit SNA version `3`
- the savestate loader accepts both v2 and v3 payloads, preserving compatibility
  with already-created Memories
- ordinary `.sna` loading also parses v3 fields when present
- the imported CRTC now exposes and restores a compact v3 state bus
- on v3 restore, the CRTC memory-address pointer is reconstructed from the
  saved CRTC counters and CRTC start/display registers because the SNA v3
  header does not directly store that HDL latch
- the Gate Array interrupt scanline counter and IRQ-active flag are saved and
  restored
- the GA vsync-delay field is emitted as inactive because the imported GA
  sequencer uses a non-linear internal encoding that should not be loaded from
  the linear SNA field without a better mapping
- savestate capture waits for a CRTC frame pulse before freezing the CPU, and
  load keeps the CPU frozen until a CRTC frame pulse after apply, with a timeout
  fallback so unusual video timings cannot hang the Pocket command forever
- boot/custom-ROM target reads were raised from 1 KiB to 4 KiB chunks, reducing
  sleep-wake boot asset round trips before the final savestate apply can become
  safe
- `scripts/pocketcpc_savestate.py` now preserves v3 headers by default instead
  of normalizing v3 snapshots down to v2

Expected next hardware proof:

- wake should be faster because `boot.rom` and `custom.rom` load through fewer
  APF target-read commands
- the Dizzy-style misframed wake should improve if CRTC phase was the missing
  state
- old v2 `.sta` files should continue to load
- `.sna` loading should continue to work for v2 files and should now use v3
  timing state for v3 files
- if Alien 8 still resumes with continuous audio or no input response, the next
  missing state is likely outside the standard v3 CRTC/GA fields, such as PSG
  internal tone/envelope counters or a wrapper-local interrupt/audio latch

## 2026-07-28 Hardware Result: Sleep Wake Correct, Perceived Latency Remains

Hardware result from the SNA v3 timing-state build:

- old v2 Memories still load correctly
- v3 `.sna` files load normally
- Alien 8 manual Memory save/load works
- Alien 8 sleep/wake restores to a functional CPC; music stops, but gameplay
  can continue
- Dizzy Kwik Snax sleep/wake restores with correct centered display
- wake still takes roughly ten to twelve seconds

Interpretation:

- SNA v3 CRTC/GA timing state fixed the correctness failures that mattered:
  display phase, reset-like wake behavior, and unresponsive CPC state
- the remaining issue is mostly perceived latency
- comparison with the GBA core suggests a visible restore progress indicator
  makes similar-duration wake flows feel less stalled
- chasing further timing reductions now is riskier than adding a non-invasive
  progress indicator, because the restore sequence is finally hardware-proven

Change made:

- expose savestate load progress from the CPC-domain restore FSM
- draw a four-pixel-high bottom-edge progress bar while a savestate load is
  active and the core is still held on the synthetic startup/wake frame
- include Pocket host-write progress as well as CPC-side restore-copy progress,
  so the indicator can move while the Pocket is still delivering the `.sta`
  blob and not only after the CPC copy phase starts
- keep the bar cosmetic only: no savestate protocol, payload, PSRAM staging, or
  restore sequencing changes
- avoid overlaying the bar on live CPC video, so restored game framing remains
  untouched

Expected next hardware proof:

- wake should still restore Alien 8 and Dizzy Kwik Snax correctly
- during the long black wake period, the Pocket display should show a thin
  bottom progress bar filling from left to right
- old v2 Memories and v3 `.sna` loading should be unchanged

Follow-up hardware result:

- sleep/wake still restored correctly
- no progress bar was visible; the Pocket showed a blank screen for roughly ten
  seconds and then switched directly to the restored game

Interpretation:

- the progress bar was only drawn through PocketCPC's synthetic startup/wake
  video path, not through live CPC video
- changing the synthetic sync style did not make the bar visible on hardware
- this suggests Pocket suppresses or blanks core video during the sleep-wake
  restore command until the core reports savestate load completion

Change made:

- remove the failed core-video progress overlay and leave savestate sequencing
  untouched
- keep the load progress signals exposed from the CPC restore FSM
- use the documented APF Host/Target command busy status path instead: the
  Analogue docs state that the lower 16 bits of a busy command status may carry
  progress information such as a percentage
- keep the initial `0x00A4` load request in APF busy state until restore
  completes, updating the busy-status low word with a 0-100 progress estimate

Expected next hardware proof:

- sleep/wake should still restore correctly
- the Pocket OS should now have command-level progress to render during the
  wake wait, matching the likely mechanism behind GBA/GBC-style progress
  display

Follow-up hardware result:

- sleep/wake and manual Memories still functioned correctly
- no visible progress bar appeared during wake

Interpretation:

- the documented `BU` progress field is syntactically valid, but hardware
  evidence suggests Pocket firmware does not render a visible progress bar for
  this host-command phase of sleep restore
- the long visible blank interval likely includes the normal startup asset
  loading phase before `cpc_rom_loaded` goes true, not just the final CPC
  savestate apply phase
- the `budude2/openfpga-GBC` path suggests the native APF progress users see in
  working cores comes from APF-owned data-slot/savestate-window transfers, not
  from a core-drawn overlay or explicit low-word progress value
- PocketCPC currently marks the required `boot.rom` and optional `custom.rom`
  slots as `deferload`, so APF only reports their size and the core later pulls
  them through target read commands

Next direction:

- commit the hardware-working savestate/sleep code before restructuring
- replace the deferred `boot.rom`/`custom.rom` target-read path with a
  budude2-style APF bridge-write loader, so Pocket owns the startup asset
  transfer and can use its native progress UI
- keep the proven savestate payload and CPC restore sequencing unchanged during
  that loader migration

References checked:

- `spiritualized1997/openFPGA-GBA` public repository and release package:
  package metadata only, no HDL source to inspect
- `budude2/openfpga-GBC` at commit
  `dd69fea79762b9b04c21f3082fb20f07d81f298a`: source is available; no explicit
  pixel progress overlay was found in the video path; its cartridge/BIOS slots
  are normal APF-loaded data slots, and its savestate window is consumed through
  FIFOs while APF owns the external transfer
- Analogue Host/Target Commands documentation:
  `https://www.analogue.co/developer/docs/host-target-commands`

## 2026-07-28 Checkpoint: Hardware-Proven Savestates Committed

Hardware result:

- Pocket Memories save/load worked
- save, play onward, restore worked
- exit core, restart core, load the saved Memory also worked
- sleep/wake restore worked on tested games, but wake remained slow at roughly
  10 seconds and did not show a visible progress bar

Repository checkpoint:

- committed the hardware-proven savestate and sleep/wake implementation before
  changing startup asset loading
- commit: `6b077bb Add hardware-proven Pocket savestates`

## 2026-07-28 Experiment: Native APF ROM Asset Loading

Reason:

- GBC shows the reference pattern for native APF progress is normal APF-owned
  data-slot transfer, not a core-drawn overlay
- PocketCPC still loaded `boot.rom` and optional `custom.rom` through deferred
  target-read commands after reset, so the long wake blank likely included work
  APF could not present as native setup progress

Change:

- `boot.rom` slot `0x200` is no longer `deferload`
- `custom.rom` slot `0x208` is no longer `deferload`
- APF maps `boot.rom` to `0x60000000` and `custom.rom` to `0x60028000`
- added `pocket_apf_write_loader.sv`, adapted from
  `budude2/openfpga-GBC/src/gb/data_loader.sv`, to consume APF bridge writes
  through a small CDC FIFO and stream bytes into the existing CPC ROM RAM
- removed the old deferred target-read ROM loader path from `core_top.sv`
- kept `.dsk`, `.cdt`, `.sna`, savestate payload, PSRAM staging, and CPC
  restore sequencing unchanged

Expected next hardware proof:

- normal core launch still loads `boot.rom` and reaches the CPC boot screen
- optional `custom.rom` still maps to upper ROM select `0x06` when present
- `.sna`, `.dsk`, `.cdt`, Pocket Memory save/load, and sleep/wake still work
- wake either shows APF-native progress during setup loading or at least does
  not regress while using the documented APF-loaded slot path

Validation:

- hardware validated on Pocket
- the Pocket now shows a native progress bar during wake
- tested wake time improved substantially, around 50% faster by user count
- committed as `f9187dc Use APF setup writes for ROM assets`

## 2026-07-28 Hardware Result: Working Save/Load/Restart Cycle

Hardware result from the next build:

- save completed
- gameplay continued after the save
- restore completed and returned to the saved state
- exiting and restarting the core still allowed the saved state to load

Interpretation:

- the remaining post-apply reset was caused by allowing the CPU to escape reset
  before T80 `DIRSet` register injection had been sampled
- holding `freeze_cpu` across reset release and the final `.sna` restore pulse
  fixed the savestate handoff
- the staged `.sna`-compatible payload plus external PSRAM approach is now
  hardware-proven for a safe save/load/restart cycle

Current limitations:

- keep savestate creation rejected during active disk or tape activity
- tape runtime position and broader adapter/FDC in-flight state remain
  follow-up work before claiming exhaustive Memories coverage

## 2026-07-28 Hardware Result: Sleep Wake Restores To Boot

Hardware result after manual Memories were working:

- two Pocket sleep/wake cycles saved successfully on sleep
- on wake, the CPC returned to the boot screen instead of the saved runtime
  state

Forensic evidence from the mounted device:

- the latest log captured the sleep-save/unload half and showed `0x00A0`
  completing with result `0x0002`
- that log ended at `Sleeping, saving resume state` and did not include the
  wake-side `0x00A4` restore sequence

Interpretation:

- manual Memories load already proves the core-defined payload and normal
  restore/apply path can work
- sleep/wake adds the Pocket boot/reset lifecycle around the same savestate
  command flow
- PocketCPC loads the required `boot.rom` through runtime target data-slot
  requests after Reset Exit, so a sleep restore can arrive while the CPC-side
  ROM/data-slot setup is not yet safe for destructive state application
- rejecting that early `0x00A4` load request lets the core continue normal boot,
  which matches the observed boot-screen wake result

Change made:

- `savestate_load` is now accepted whenever no save/load operation is already
  active, instead of being rejected because runtime safety gates are not yet
  true
- after accepting load, the controller reports busy and holds `freeze_cpu`
  while waiting
- restore does not begin reading the staged blob until bridge-side host writes
  have drained into PSRAM
- after the staged blob is readable, the controller copies RAM immediately and
  waits for the normal load-safe gates only before the final `.sna` register
  apply pulse
- the CPC-side wait state includes a short settle period before trusting the
  synchronized bridge-ready level, so it cannot observe stale readiness from
  before the Pocket's final host writes
- bridge-side writes are allowed to keep draining while the load FSM is in that
  wait-for-blob state, avoiding a deadlock where `load_busy` prevents the last
  Pocket-provided words from reaching PSRAM
- the existing debug flag word now latches whether a load had to wait for the
  blob/runtime readiness path before applying

Expected next hardware proof:

- sleep should still save successfully
- wake should keep the host-side load command busy until `boot.rom` and
  optional `custom.rom` loading have finished, then restore the saved CPC state
- if wake still returns to boot, the next log should reveal whether `0x00A4`
  was rejected, stayed busy, or completed before the CPC-side ready gates became
  true

## 2026-07-28 Hardware Result: Sleep Wake Waits Then Boots

Hardware result from the next sleep/wake build:

- the Pocket stayed on a black screen for roughly three seconds during wake
- the display then briefly flashed the same uninitialized video seen during a
  fresh core startup
- the CPC then reached the boot screen instead of the saved runtime state

Forensic evidence from the mounted device:

- `/Volumes/Pocket/System/user_sleepstate.sta` exists and is the expected small
  sleep-state wrapper size
- `scripts/pocketcpc_savestate.py info` identifies it as a valid PocketCPC
  `.sta` wrapper containing a version-2 `.sna` payload
- payload size is `65792` bytes, matching a 64K CPC snapshot image
- there is no trailing data after the payload
- no new wake-side Pocket log was written; the newest log still ends at the
  sleep-save/unload side

Interpretation:

- the sleep save is not empty or obviously malformed
- accepting the early sleep-wake load request changed behavior, so the wake path
  is now waiting in or near the savestate controller instead of immediately
  falling through to boot
- the previous sleep fix serialized all boot-ROM/custom-ROM setup before
  starting the heavy PSRAM-to-CPC-RAM restore copy, which wastes wake-time
  budget
- the savestate-specific ready gate did not include `cpc_custom_rom_ready`,
  even though `cpc_custom_rom_ready` is part of the CPC machine reset condition
- that gap could let savestate `load_safe` go true after `boot.rom` finished
  but before custom-ROM loading completed or failed, allowing the final
  savestate apply to be reset over immediately

Change made:

- keep accepting early `savestate_load` requests
- wait only for the Pocket-written bridge blob to drain into PSRAM before
  reading/copying staged savestate data
- copy the staged `.sna` RAM into CPC RAM immediately, while the CPC remains
  frozen/reset
- wait for `load_safe` only at `LOAD_COMMIT`, just before asserting the final
  `.sna` register/state apply pulse
- include `cpc_custom_rom_ready` in the savestate-specific runtime-ready gate,
  so savestate final apply cannot run while the CPC machine is still being held
  reset by custom-ROM setup

Expected next hardware proof:

- wake should spend less time with the host-side load command busy because RAM
  restore overlaps boot asset setup
- the final apply should no longer occur while `!cpc_custom_rom_ready` can
  reset over the restored state
- if it still returns to boot, the likely next area is a host reset edge after
  `0x00A4` acceptance or completion, not the staged payload

## 2026-07-28 Hardware Result: Sleep Works, SNA Regresses

Hardware result from the next build:

- manual Memories still saved and loaded correctly
- sleep/wake also restored correctly
- wake restore took roughly five seconds
- normal `.sna` snapshot loading regressed; loaded content often flashed or
  beeped briefly, then the CPC reset

Interpretation:

- the staged savestate payload and sleep/wake sequencing are now functionally
  correct
- the previous change was too broad: adding `cpc_custom_rom_ready` to the
  global `dataslot_runtime_enable` changed timing for ordinary data-slot
  clients, including `.sna`, disk, tape, and snapshot-save paths
- `.sna` loading also still used the old fragile apply handoff: it released
  `snapshot_busy_reset` before pulsing `sna_load` and did not freeze the CPU,
  matching the failure mode previously fixed in the savestate loader

Change made:

- restore `dataslot_runtime_enable` to the normal data-slot definition:
  `cpc_loader_done & cpc_rom_loaded`
- add a separate `cpc_savestate_runtime_ready` gate for savestate safety:
  `dataslot_runtime_enable & cpc_custom_rom_ready`
- use that savestate-specific gate only for savestate save/defer/load safety
- add a `.sna`-loader `freeze_cpu` output and wire it into the CPC machine
- lengthen the `.sna` final apply sequence to match the proven savestate
  pattern: hold reset briefly, release reset while CPU remains frozen, pulse
  `sna_load`, then release the CPU

Expected next hardware proof:

- manual Memories and sleep/wake should remain functional
- normal `.sna` loading should return to working behavior
- if wake remains correct but still takes roughly five seconds, the next
  optimization target is boot/custom-ROM load latency during wake, not the
  correctness of state restore

## 2026-07-28 Tooling: Snapshot/Savestate Conversion

Now that the PocketCPC `.sta` payload is hardware-proven as a `.sna`-compatible
blob, `scripts/pocketcpc_savestate.py` can convert in both directions:

- `.sta` to `.sna`: locate `MV - SNA`, parse the standard header, and extract
  exactly the core payload length implied by the SNA memory-size field
- `.sna` to `.sta`: preserve a user-supplied PocketCPC `.sta` template wrapper,
  replace the embedded core payload, and patch the observed 64K/128K wrapper
  size markers

Current behavior:

- the script can synthesize the observed PocketCPC `.sta` wrapper from scratch
  and uses a blank thumbnail for no-template output
- generated wrappers use the input `.sna` filename as the asset label stored in
  the Pocket-side metadata unless `--asset-name` overrides it
- `--template` remains available when preserving a real PocketCPC thumbnail or
  Pocket-side display metadata matters
- by default, source SNA v1 headers are normalized to v2 while v2/v3 payloads
  are preserved, because PocketCPC savestate loading now accepts v2 and v3
  payloads

This keeps conversion aligned with the working hardware path while limiting the
undocumented Pocket container handling to fields observed in real Memories.

Real-device validation:

- a 128K PocketCPC savestate created on hardware at
  `/Volumes/Pocket/Memories/Save States/stilvoid.PocketCPC/20260728_011221_USR_00000000_boot.sta`
  parsed as SNA v2, `mem_kb=128`, `machine_type=2`, payload offset `0x254`,
  payload length `131328`, and wrapper size `184688`
- the Pocket device log reported the same APF export size: `131328` bytes
- `.sta` to `.sna` extraction produced a 131328-byte raw snapshot
- `.sna` back to `.sta` using the same 128K `.sta` as template was
  byte-for-byte identical to the original file
- wrapping that extracted 128K `.sna` with a 64K `.sta` template produced a
  structurally correct 128K `.sta` with wrapper unit bytes `2,2`
- wrapping the known 64K `dizzy.sna` with the 128K `.sta` template produced a
  structurally correct 64K `.sta` with wrapper unit bytes `1,1`
- hardware validation then confirmed both converted outputs work: extracting
  the latest 128K `.sta` to `.sna` loaded correctly through `Load Snapshot`,
  and converting `dizzy.sna` to `.sta` with the latest savestate as template
  loaded correctly through the Pocket `Memories` system

Follow-up wrapper analysis:

- official Analogue documentation covers the core blob handoff but does not
  document a public `.sta` container format
- comparing PocketCPC, Spiritualized GB/GBA, and budude2 GB Memories showed the
  same generic wrapper shape
- offset `0x000`: `01 53 50 41`
- offset `0x004`: little-endian core payload size
- offset `0x008`: little-endian end offset of the core payload
- offset `0x010`: metadata count `10`
- offset `0x014`: CRC32 of the core folder/id, for PocketCPC
  `crc32("stilvoid.PocketCPC") == 0xBE3D9CCC`
- offset `0x044`: author string
- offset `0x064`: core name string
- offset `0x084`: core version string
- offset `0x0A4`: asset filename string
- offset `0x1A4`: platform id string
- offset `0x1B4`: platform display name string
- the trailing thumbnail block starts with `20 49 50 41`, followed by
  little-endian dimensions `121x109`, then `121*109` four-byte pixels
- generating a blank thumbnail is enough to create a structurally valid wrapper
  without preserving a template thumbnail
- generated 64K and 128K no-template outputs have prefixes byte-for-byte
  identical to real PocketCPC wrappers for the same payload size

Current tooling direction:

- `--template` is now optional
- no-template `.sna` to `.sta` generation has been directly validated on Pocket
  hardware, including acceptance of the generated blank thumbnail
- template mode remains useful when preserving a real thumbnail or any
  Pocket-side display metadata matters

UI label finding:

- Pocket-created Memories currently appear with the label `boot`
- the observed wrapper metadata stores `boot.rom` at offset `0x0A4`, matching
  the required asset in `data.json`
- runtime `.sna`, `.dsk`, and `.cdt` loads use separate deferred data slots,
  and the documented savestate command response exposes only support, address,
  and size, not a title or asset-name field
- generated converter output therefore defaults the wrapper asset label to the
  input `.sna` filename, but Pocket-created runtime Memories may remain
  `boot` unless a supported APF content-title mechanism is found

## 2026-07-28 Hardware Result: Payload Good, Post-Apply Reset

Hardware result from the next build:

- save completed
- load completed according to the Pocket host
- the expected screen appeared briefly
- the CPC then behaved as if it had reset

Forensic evidence from the mounted device:

- latest savestate:
  `/Volumes/Pocket/Memories/Save States/stilvoid.PocketCPC/20260728_002301_USR_00000000_boot.sta`
- latest log:
  `/Volumes/Pocket/System/Logs/stilvoid.PocketCPC_20260728_002251.txt`
- the Pocket payload begins with `MV - SNA` at offset `0x254`
- parsing the payload as a `.sna` header gives plausible live CPU state:
  `PC=0xB985`, `SP=0xBFF7`, `machine_type=0`, `mem_kb=64`
- comparing against the known Dizzy fixture shows only small runtime deltas
  after the previous RAM-capture fix, not the earlier alternating-word
  corruption
- the Pocket log shows savestate load result `0x0002`, so this is no longer a
  host/protocol rejection

Interpretation:

- save/export and RAM capture are now good enough to restore visible state
- the remaining failure is in the post-load apply/release sequence or in a
  machine-control field that is not surviving the handoff
- the most likely simple failure is that the CPU is allowed to run from reset
  before the saved T80 registers are sampled

Change made:

- hold `freeze_cpu` from savestate-load acceptance until after `sna_load` has
  been sampled
- assert `snapshot_busy_reset` as soon as the `.sna` magic is validated
- lengthen the final apply sequence and pulse `sna_load` while reset is low but
  the CPU is still frozen
- emit `SSOK` debug bursts as well as `SSLE`, including top-level reset/menu
  flags and live `{PC, SP}` after a completed load

Expected next hardware proof:

- if the load now resumes correctly, the fault was reset-vector execution
  before register restore
- if the screen still resets, the `SSOK` burst should show whether live `PC/SP`
  match the saved header or whether a top-level reset source fired after apply

## 2026-07-27 Hardware Result: Header Fixed, RAM Capture Corrupt

Hardware result from the next build:

- save completed
- load completed instead of failing
- the screen changed to a recognizable but corrupted Dizzy title screen
- corruption appeared as vertical stripes
- the CPC appeared crashed after load

Forensic evidence from the mounted device:

- latest savestate:
  `/Volumes/Pocket/Memories/Save States/stilvoid.PocketCPC/20260727_233859_USR_00000000_boot.sta`
- latest logs:
  `/Volumes/Pocket/System/Logs/stilvoid.PocketCPC_20260727_233850.txt`
- the Pocket payload now contains the expected `MV - SNA` signature at offset
  `0x254`
- the Pocket log reports savestate load completion (`0x00A4` result `0x0002`)
- comparing the `.sta` payload against the known starting snapshot
  `/Volumes/Pocket/Assets/amstrad/common/dizzy.sna` shows the payload header is
  sane but RAM has a strong structural pattern, for example repeated
  `00 00, real word, 00 00, real word` regions

Interpretation:

- the APF save/export one-word-buffer fix worked
- the remaining failure is not primarily the load transaction
- the saved RAM payload is already corrupt before load applies it
- the visible vertical stripe pattern and crashed CPC match corrupted restored
  RAM, including CPU-visible program bytes

Root cause:

- the savestate save FSM was treating `capture_ram_word_data` as if it updated
  immediately after changing `capture_ram_word_addr`
- `cpc_ram_rom.sv` routes the capture path through the same `altsyncram` read
  port used for video/capture readback
- that port has a registered address path, so each requested word address must
  be held for a full clock before sampling the data
- the `.sna` snapshot saver had the same fragile capture sequence

Change made:

- added explicit address-settle states before sampling each 16-bit CPC RAM word
  in `cpc_savestate_controller.sv`
- kept `capture_ram_rd` asserted across the settle/sample phases so the RAM
  read mux does not fall back to live video address between adjacent reads
- applied the same fix to `pocket_sna_save_dataslot.sv`
- left APF savestate handshake, PSRAM staging, and `.sna` payload shape
  unchanged

Expected next hardware proof:

- a newly saved `.sta` should still contain `MV - SNA`
- the RAM payload should no longer show alternating stale/zero 16-bit words
- if load still fails after that, the next bug is likely in state application
  rather than save/export/capture

Validation:

- `make validate` succeeded on 2026-07-27 after this change with 0 errors and
  10 warnings
