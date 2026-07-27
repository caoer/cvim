# Bounds guard over `vim.treesitter.get_node_text` (§6 row 9).
#
# Upstream bug neovim/neovim#38303, root #37091. The highlighter's decoration
# provider and the injection-language resolver read a node's byte range through
# `nvim_buf_get_text` BEFORE the tree re-parses after a buffer edit — classically
# `dd` in a larger file. The stale range is out of bounds, `nvim_buf_get_text`
# throws, and core spams once per redraw:
#
#   Error in decoration provider ... (ns=nvim.treesitter.highlighter):
#   Index out of bounds
#
# Core catches it and self-corrects on the next redraw, so the damage is noise,
# not corruption. The bug is present on stable and nightly alike, so there is no
# version to move to.
#
# `vim.treesitter.get_node_text` is the single Lua entry point both callers go
# through, and they resolve it at call time — so wrapping it here makes an
# out-of-bounds read return "" (skip the text for one stale frame) instead of
# throwing. Remove once #38303 lands bounds checks upstream.
#
# `vim.g.ts_bounds_guard_catches` counts suppressions. It is the only way to
# tell "the guard is working" from "the bug never fired", which is what makes
# this verifiable rather than assumed.
#
# empty:   with no treesitter parsers attached the wrapper is installed and
#          never invoked; the counter stays 0 and nothing changes.
# partial: a single out-of-bounds frame yields "" for that node — one frame
#          renders without that node's text, the next redraw is correct.
# error:   double-loading is idempotent — `ts.__bounds_guarded` makes a second
#          evaluation a no-op, so the wrapper never stacks on itself.
#          Capture: results/captures/u9a-ts-bounds-guard.txt.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLuaPre = ''
      do
        local ts = vim.treesitter
        if ts and type(ts.get_node_text) == "function" and not ts.__bounds_guarded then
          local orig = ts.get_node_text
          vim.g.ts_bounds_guard_catches = 0
          ts.get_node_text = function(...)
            local ok, res = pcall(orig, ...)
            if ok then
              return res
            end
            vim.g.ts_bounds_guard_catches = (vim.g.ts_bounds_guard_catches or 0) + 1
            return ""
          end
          ts.__bounds_guarded = true
        end
      end
    '';
  };
}
