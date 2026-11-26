# CLAUDE.md

Guide pour Claude Code sur ce dépôt (`cool_fox` / `victory`, runtime Rust Direct3D 12).

## Commandes de vérification (utilisées par /dev-loop)

- **Tests** : `cargo test --workspace --locked`
- **Type check** : `cargo check --workspace --all-targets --locked`
- **Lint** : `cargo clippy --workspace --all-targets --locked -- -D warnings`

Les trois vérifications sont disponibles. Projet Rust, toolchain épinglée `1.98.1` (voir `rust-toolchain.toml`). Le workspace inclut `xtask` ; `cargo test --workspace` exécute aussi la vérification de politique d'assets (`repository_passes_policy`, cf. `docs/asset-policy.md`).
