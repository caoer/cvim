# Text objects, surround, pairs, and indentation detection
#
# empty:   a buffer with no matching text object — the operator simply does nothing and the buffer is unchanged.
# partial: a filetype without a treesitter grammar loses mini.ai's function/class targets but keeps its bracket and quote ones.
# error:   none reachable; every module here is an editing operator, so a miss is a no-op rather than a failure.
#
# ZT gated this set on 2026-07-27 (decisions/u3-mini-module-set.md). All five
# mini modules ship. The measured input that made it a taste question rather
# than a budget one: mini.nvim is ONE package (v0.18.0), so five modules cost
# exactly what one costs and U12 should expect no closure saving from trimming
# them.
#
# `s` IS CLAIMED TWICE, DELIBERATELY. mini.surround uses `s` as an operator
# prefix; flash (motions.nix) binds `s` in normal/visual as a jump. They
# coexist under nixvim's defaults and no conflict appeared in the lab. It looks
# like a collision on paper, so it is written down here — do not "fix" it.
# Accepted consequence, raised with ZT before the choice: plain `s`
# (substitute-char) is shadowed; `cl` does the same thing.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins.mini = {
      enable = true;
      modules = {
        # Treesitter-aware `a`/`i` text objects plus next/last variants
        # (`cin(` = change in NEXT parens). Purely additive — it extends the
        # existing a/i motions rather than rebinding anything.
        ai = { };

        # `saiw"` to wrap, `sd"` to delete, `sr"'` to replace.
        surround = { };

        # Auto-closes brackets and quotes as you type.
        pairs = { };

        # vim-unimpaired-style `[`/`]` navigation pairs: `[b`/`]b` buffers,
        # `[d`/`]d` diagnostics, `[c`/`]c` comments, and around a dozen more.
        bracketed = { };

        # `gS` toggles a single-line construct to multi-line and back. Earns
        # its place in nix attrsets, Go structs and JSON.
        splitjoin = { };
      };
    };

    # Indentation detection, gated separately by ZT
    # (decisions/u3-indent-detection.md).
    #
    # Neovim's editorconfig support is BUILT IN and nixvim enables it by
    # default (`editorconfig.enable`, modules/editorconfig.nix), so
    # `.editorconfig` files are already honoured with no plugin at all. This
    # layer relies on that and does not re-enable it — the reliance is stated
    # so a later unit does not disable it believing it unused.
    #
    # vim-sleuth covers only the gap: a file with NO `.editorconfig`, where it
    # guesses indentation from surrounding content instead of silently applying
    # our defaults and mixing styles into the diff.
    plugins.sleuth.enable = true;
  };
}
