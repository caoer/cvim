# cvim

ZT's Neovim, built directly on [nixvim][]. One flake, three packages, no
distro underneath it.

cvim rides nixvim's nixpkgs pin — there is no `nixpkgs` input here and no
`follows` on `nixvim`. That is deliberate: matching nixvim's pin keeps the
intermediate plugin derivation hashes identical to the ones the community
cache already holds.

The binary is `cvim`. It is the same `nvim` under a second name, so cvim can
be installed next to a system Neovim without either one shadowing the other.

## Packages

| Package  | What it is | Ships |
| -------- | ---------- | ----- |
| `default` | The workstation editor — every area on | yes |
| `server`  | A comfortable remote editor — no language toolchains, small enough for small hosts | yes |
| `lab`     | `default` plus the scratch layer in `lab/` | never |

```sh
nix run github:caoer/cvim -- --version
nix build github:caoer/cvim#server
```

Hosts install by pinned revision, never by the bare `github:caoer/cvim` ref —
a mutable ref means a full local evaluation, which is more than a small host
has:

```sh
nix profile install github:caoer/cvim/<rev>
nix profile wipe-history --older-than 14d
```

## Layout

```
flake.nix           # evalNixvim, the three packages, checks, substituters
modules/
  options/          # the cvim.* surface: 8 feature areas + the profile cascade
  core/  ui/  picker/  git/  lsp/  lang/  ai/  dap/  zt/
lab/
  lab-<layer>.nix   # per-layer scratch, imported only by packages.lab
```

`modules/options/` says what a user can turn on; `modules/<layer>/` says how.
One implementation unit owns one layer directory and one options file, so two
people are never editing the same file.

Two house rules hold everywhere under `modules/options/`:

- `false` and `null` are first-class in every declared type. A feature you
  cannot turn off, or a setting you cannot explicitly blank, is a defect.
- Profiles write `mkDefault` only, so choosing a profile never costs you the
  ability to override one option inside it.

## Customizing a host

The evaluated configurations are exported, so a host extends cvim with the
module system rather than by forking it:

```nix
inputs.cvim.nixvimConfigurations.${system}.default.extendModules {
  modules = [ { cvim.ai.enable = false; } ];
}
```

The same handle is on the package as `passthru.config` / `passthru.options`.
Both survive because `bin/cvim` is added by extending the existing package's
`postBuild` — wrapping the package in a fresh `symlinkJoin` would drop the
passthru and break every host that extends it.

## The lab loop

Plugins get trialled in `lab/`, verified by eye, and only then hardened into a
layer:

```sh
$EDITOR lab/lab-picker.nix          # add a candidate
just lab                            # nix build .#lab
./result/bin/cvim some/test/file    # in a tmux pane
just verify-pane %3 picker-zero-results
```

`just verify-pane <pane> <name>` runs `tmux capture-pane -e -p`, which keeps
the colour and attribute escapes — a plain-text capture cannot show whether a
statusline is readable. Captures land in `$CVIM_CAPTURE_DIR`, or in a
gitignored `captures/` when that is unset.

Anything trialled and kept moves into `modules/<layer>/`; anything trialled
and rejected gets deleted. `lab/` is empty at rest, and it is reachable from
`packages.<system>.lab` and nowhere else.

The lab build sets `vim.g.cvim_lab`, which is absent from `default` and
`server`. That makes the isolation checkable instead of merely intended:

```sh
nix eval .#nixvimConfigurations.aarch64-darwin.default.config.globals --apply \
  'g: !(g ? cvim_lab)'   # => true
```

## Checks

`nix flake check` builds `build.test` for all three packages — a headless
Neovim start that fails on any error or warning during init.

[nixvim]: https://github.com/nix-community/nixvim
