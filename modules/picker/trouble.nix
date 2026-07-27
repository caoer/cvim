# trouble.nvim — the diagnostics list.
#
# Scope note: this layer binds trouble's *list* modes (diagnostics, symbols,
# quickfix, loclist). Trouble's LSP-location modes (lsp_definitions,
# lsp_references) are U7's to bind, because U7 owns the `g`-prefix LSP
# keymaps. ZT chose trouble's modes over glance.nvim for that job on
# 2026-07-27; glance does not ship.
{ config, lib, ... }:
let
  cfg = config.cvim.picker;
in
{
  config = lib.mkIf cfg.enable {
    plugins.trouble = {
      enable = true;

      settings = {
        # The empty state has to be legible, and these two options are the
        # whole of it. `warn_no_results = true` emits "no results" when a mode
        # finds nothing; `open_no_results = false` keeps an empty window from
        # opening to say so. Both are upstream defaults — pinned here because
        # this layer's comment header makes a claim about the empty state, and
        # a claim resting on an unstated default is a claim resting on
        # nothing.
        warn_no_results = true;
        open_no_results = false;

        # Off by default upstream, and stays off: auto_refresh re-runs the
        # active mode on every diagnostic change, which on a large workspace
        # turns an LSP publishDiagnostics storm into a redraw storm. `r`
        # refreshes on demand.
        auto_refresh = false;
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        options.desc = "Diagnostics (current buffer)";
      }
      {
        mode = "n";
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Diagnostics (workspace)";
      }
      {
        mode = "n";
        key = "<leader>xs";
        action = "<cmd>Trouble symbols toggle<cr>";
        options.desc = "Symbols outline";
      }
      {
        mode = "n";
        key = "<leader>xq";
        action = "<cmd>Trouble qflist toggle<cr>";
        options.desc = "Quickfix list";
      }
      {
        mode = "n";
        key = "<leader>xl";
        action = "<cmd>Trouble loclist toggle<cr>";
        options.desc = "Location list";
      }
    ];
  };
}
