# cvim — agent instructions

Read `README.md` first: architecture, the three packages, the lab loop, and
the checks all live there. This file only adds what an agent needs beyond it.

## Shipping a change

A change is not done at push. Hosts install cvim by pinned revision
(`nix profile install github:caoer/cvim/<rev>`), so a push updates no
machine — every host re-pins to pick it up.

The chain: edit → `nix build .#` → verify against `./result/bin/cvim` →
commit + push → re-pin on each host → verify against the installed binary.

Machine-local deploy steps live in `CLAUDE.local.md` — gitignored, one per
machine, because the install method and profile paths are host state, not
repo content. If it is missing on this machine, ask before assuming how
cvim is installed here.

## Verification

Build passing is not verification — nix config is inert until an editor
runs it. Verify in the built editor:

- headless: `./result/bin/cvim --headless <file> "+lua ..."` and read
  state back (extmarks, keymaps, module fields).
- visual: tmux pane + `tmux capture-pane -e -p` (the `-e` keeps color
  escapes; a plain capture cannot show whether a highlight painted).
- `nix flake check` before commit — it runs `build.test` (headless start,
  fails on any init error or warning).
