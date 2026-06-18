# Known-good Pocket bitstreams

Each file in this directory is a packaged Pocket `bitstream.rbf_r` copied from
a user-confirmed good checkpoint before that checkpoint was committed.

Naming convention:

- `YYYYMMDD-short-description.rbf_r`

Keep these files aligned with git history so a later regression can be tested
against a known hardware image without rebuilding an older tree first.
