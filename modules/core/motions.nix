# Motions, project-wide replace, and LSP rename preview
#
# empty:   flash with no match shows no labels and leaves the cursor put; grug-far with no matches shows an empty result section, not an error.
# partial: grug-far streams matches as ripgrep produces them, so a large search renders progressively rather than blocking.
# error:   grug-far surfaces a missing or failing `rg` in its own buffer as visible text; flash and inc-rename cannot fail without a target.
#
# ZT gated this cluster on 2026-07-27 (decisions/u3-motions-cluster.md).
# flash, grug-far and inc-rename ship. multicursors.nvim was DROPPED — on
# provenance, not behaviour: it worked in the lab, but its last upstream commit
# was 2025-02-26 (~17 months) under a single maintainer, making it the
# candidate most likely to break on a future Neovim release with nobody to fix
# it. That is §4 convention 1 doing something a functional test never would.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins = {
      # `s` + two characters labels every match for a direct jump; also
      # enhances `f`/`t` and gives treesitter-node selection on `S`. See
      # text.nix for why sharing `s` with mini.surround is fine.
      flash.enable = true;

      # ripgrep-backed project-wide search and replace in a preview buffer —
      # every match visible before anything is applied.
      #
      # Runtime writes comply with the state-dir rule: its history goes to
      # `vim.fn.stdpath('state') .. '/grug-far'` (lua/grug-far/opts.lua:462),
      # i.e. under $XDG_STATE_HOME, never into the store. Checked rather than
      # assumed, because a plugin that persists history is exactly where the
      # silent-store-write class shows up.
      grug-far.enable = true;

      # Live preview of an LSP rename as you type it, before committing.
      # Inert until an LSP with rename capability attaches — a value
      # dependency on the LSP layer, not a correctness one, and expected
      # behaviour rather than a defect.
      inc-rename.enable = true;
    };
  };
}
