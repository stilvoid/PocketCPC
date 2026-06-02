# Risk Register

| Risk | Severity | Notes | Mitigation |
| --- | --- | --- | --- |
| MiSTer `hps_io` coupling is deeper than expected | High | File loading, menu state, status bits, disks, keyboard all flow through it. | Treat `hps_io` replacement as first-class bridge layer, not a small shim. |
| DSK write support is awkward on APF | High | MiSTer uses block-like SD semantics; Pocket asset slot semantics may differ. | MVP read-only DSK. Add write-back later after block cache design is stable. |
| CPC keyboard is unpleasant on handheld | High | CPC software often expects actual keyboard. | Virtual keyboard plus mapped shortcuts. Dock keyboard later. |
| Timing closure on Pocket | Medium | MiSTer target has more headroom. | Disable non-MVP features, simplify video filters, constrain clocks early. |
| GPL obligations | Medium | MiSTer Amstrad is GPL. | Keep source public-compatible, preserve notices, document provenance. |
| ROM legality | Medium | ROMs cannot be distributed casually. | Require user-supplied `boot.rom`; document hashes/offsets only. |
| Video timing/scaler mismatch | Medium | CPC timings are not console-clean. | Use Pocket scaler-friendly output first, exact timings later. |
| Spectrum +3 similarity overestimated | Medium | Shared Z80/FDC does not mean shared machine architecture. | Reuse wrapper/platform lessons only. |
| Snapshots require many internal state injection points | Low for MVP, high later | MiSTer has logic, but APF streaming adaptation is work. | Defer. |
