# CLAUDE.md

Guidance for working in this repository.

## What this is

`cool_fox` / **VIctory** — a native Windows runtime that runs an Xbox Series
title on PC. It loads the title's native x86-64 executable, implements the
console's APIs on the host, and translates the console's GPU work and shaders
to host Direct3D 12. This repo is a community continuation fork; see
[README.md](README.md) for the player-facing description and lineage.

A Rust workspace (edition 2024, resolver 3). Windows-only runtime; some crates
are platform-neutral and testable anywhere.

## Rule #1 — the asset policy (read before adding files)

**Nothing from the game is ever stored in this repository** — no assets, no
part of the executable, nothing derived from either (converted assets,
disassembly, shader dumps, extracted tables, screenshots). Full rules in
[docs/asset-policy.md](docs/asset-policy.md).

- Allowed: our own format code, build identities (BLAKE3, CodeView GUID/age),
  per-build hook offsets under names we choose, byte-pattern signatures, small
  interop constants, synthetic test data we generate.
- The single exception is `crates/victory-formats/src/bcpack-tables.bin`,
  whitelisted in `xtask/src/policy.rs`. Do not add others.
- Enforced by `cargo xtask policy` — it runs in CI (the `repository_passes_policy`
  test) and as a pre-commit hook. Install the hook with `cargo xtask install-hooks`.
- Game-derived output (caches, converted assets, logs with game data) must be
  written **outside** any directory containing the `.victory-root` marker. Tools
  refuse otherwise (`victory_core::ensure_outside_repo`). User paths live in
  `victory.toml` (git-ignored), not in the tree.

## Layout

| Path | Role |
|------|------|
| `crates/victory-core` | config, asset-policy guard, logging |
| `crates/victory-pe` | read-only PE32+ / import-library analysis |
| `crates/victory-loader` | prepare, map, bind, start the title image (TLS, crash reporter) |
| `crates/victory-hle` | console API implementations, host pass-through policy, import resolution |
| `crates/victory-gpu` | D3D12.X objects / command lists / GPU memory → host D3D12 |
| `crates/victory-shader` | Xbox shader containers → host shaders (SSA, EXEC removal, resource tracing) |
| `crates/victory-formats` | texture layouts/tiling, BCPack, audio codecs (XMA, Opus) |
| `crates/victory-pipeline` | converter trait, content-addressed cache |
| `crates/victory-game` | title-specific formats, build identities, hooks (the only non-platform crate) |
| `apps/victory` | `victory` CLI front end |
| `xtask` | asset-policy check, git-hook install |
| `tests/fixtures` | standalone fixture crates (e.g. `hle-probe`), excluded from the workspace, built on demand by integration tests |

More detail, with the data-flow diagram and import-resolution order, in
[docs/architecture.md](docs/architecture.md). Design rationale and measurements
in [docs/findings.md](docs/findings.md); debug switches in
[docs/README-fxceless.md](docs/README-fxceless.md); frame replay in
[docs/replay.md](docs/replay.md).

## Building

Toolchain is pinned in `rust-toolchain.toml` (1.98.1, `x86_64-pc-windows-msvc`,
with `rustfmt` + `clippy`). Needs MSVC build tools.

```powershell
cargo build --release --locked -p victory      # the player build
cargo build --profile diag -p victory --features diagnostics   # dev build (release codegen + diagnostics, in target/diag)
cargo check --locked -p victory                 # fast compile check
```

Always pass `--locked` (CI does). The `diag` profile is what measurements and
`scripts\play.ps1` use by default; it lands in `target/diag` so it does not
evict the plain release build.

## CI must pass (run these before claiming done)

CI is Windows-only ([.github/workflows/ci.yml](.github/workflows/ci.yml)):

```powershell
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --locked
```

Clippy warnings are denied. `cargo test --workspace` includes the asset-policy
check. Some lints are intentionally relaxed workspace-wide (see
`[workspace.lints]` in [Cargo.toml](Cargo.toml)) — prefer fixing new code over
widening those allows.

### Verification commands (used by /dev-loop)

The `/dev-loop` orchestrator maps the three checks to:

- **Tests** : `cargo test --workspace --locked` (also runs the asset-policy
  check `repository_passes_policy`, cf. [docs/asset-policy.md](docs/asset-policy.md))
- **Type check** : `cargo check --workspace --all-targets --locked`
- **Lint** : `cargo clippy --workspace --all-targets --locked -- -D warnings`

## Conventions

- `rustfmt.toml`: `max_width = 100`, field-init shorthand. Run `cargo fmt`.
- `unsafe_op_in_unsafe_fn` and `unused_must_use` are denied; write `unsafe`
  blocks explicitly. New unsafe should carry a `SAFETY:` comment
  (`undocumented_unsafe_blocks` is allowed only because older blocks lack one).
- Runtime behaviour is gated by `VICTORY_*` environment variables, each
  documented in a comment where it is read (grep `VICTORY_` to find one).
- Internal crate deps go through `[workspace.dependencies]` as `path =`.

## Running a title (needs the user's own legal dump)

```powershell
copy victory.example.toml victory.toml          # then set game_dir etc. to paths OUTSIDE the repo
$env:VICTORY_GAME_DIR = 'D:\Games\MyDump'
scripts\play.ps1 -Exe <path to your copy's executable>   # -Safe disables the newer fast paths
```

CLI commands (`apps/victory/src/main.rs`): `inspect`, `census`, `lib-exports`,
`shader-info`, `translate`, `shaders`, `warm`, `run` (`--execute` to actually
start), `config` (shows and checks the resolved config). `replay` exists only in
diagnostics builds.

## Attribution for commits/PRs

This fork keeps upstream history; commits taken from elsewhere name the commit
and its author. The repo is GPL-3.0-or-later.
