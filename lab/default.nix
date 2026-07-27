# The lab: a scratch layer for trialling plugins before they are hardened into
# a real layer module.
#
# This directory is imported by `packages.<system>.lab` and by nothing else.
# If a lab module ever reaches `default` or `server`, that is a bug in
# flake.nix, not a matter of taste — a half-trialled plugin must never ship.
#
# One file per layer, so two agents trialling different layers never touch the
# same file. Add your candidates to your own `lab-<layer>.nix`, build
# `.#lab`, verify in a pane with `just verify-pane`, then move what survives
# into `modules/<layer>/` and empty the scratch file again.
{
  # The marker that makes "lab never leaks" checkable rather than merely
  # intended: `vim.g.cvim_lab` is true in the lab build and absent everywhere
  # else, so `nix eval` can prove which one you are holding.
  config.globals.cvim_lab = true;

  imports = [
    ./lab-core.nix
    ./lab-ui.nix
    ./lab-picker.nix
    ./lab-git.nix
    ./lab-lsp.nix
    ./lab-lang.nix
    ./lab-ai.nix
    ./lab-zt.nix
  ];
}
