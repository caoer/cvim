# Window navigation and the manual-format binding.
#
# Plugin-specific keymaps live with their plugin in ./plugins.nix, so this
# file stays the editor-wide set.
#
# `<leader>` NOTE — cvim sets no `mapleader` on any branch as of 2026-07-27,
# so every binding below currently resolves to backslash, not Space. That is
# U3 core's to fix (`54396085`); a layer unit writing a global would be the
# ownership violation the carve exists to prevent. These are written normally
# and correct themselves when the global lands. Do not read "the keymap exists
# and carries a desc" as evidence that it is reachable — that check passes
# perfectly with the wrong leader.
#
# Editor-surface states:
#   empty    A window-nav key with no window in that direction is a no-op;
#            vim does not error or wrap.
#   partial  `<leader>h` is also the prefix for hurl's buffer-local
#            `<leader>h*` maps (./plugins.nix), so inside a hurl buffer it
#            waits `timeoutlen` before resolving to window-left. Inherited
#            from cnixvim, flagged rather than silently changed.
#   error    `<leader>F` with no conform formatter for the filetype falls back
#            to the LSP (`lsp_format = "fallback"`); with neither, conform
#            reports it in `:messages` and the buffer is untouched.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;

  # Window navigation is the same four directions over four key families, so
  # it is generated rather than written out sixteen times. Each entry still
  # carries its own `desc` — U12 asserts that, and a generated keymap without
  # one fails the same as a hand-written one.
  directions = [
    {
      key = "h";
      arrow = "Left";
      desc = "Go to left window";
    }
    {
      key = "j";
      arrow = "Down";
      desc = "Go to below window";
    }
    {
      key = "k";
      arrow = "Up";
      desc = "Go to above window";
    }
    {
      key = "l";
      arrow = "Right";
      desc = "Go to right window";
    }
  ];

  windowNav = lib.concatMap (d: [
    {
      mode = "n";
      key = "<leader>${d.key}";
      action = "<C-w>${d.key}";
      options = {
        inherit (d) desc;
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<${d.arrow}>";
      action = "<C-w>${d.key}";
      options = {
        inherit (d) desc;
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<S-${d.arrow}>";
      action = "<C-w>${d.key}";
      options = {
        inherit (d) desc;
        silent = true;
      };
    }
    {
      # Terminal mode needs the `wincmd` form: <C-w> is the terminal's own
      # word-erase, so it never reaches vim as a window command.
      mode = "t";
      key = "<S-${d.arrow}>";
      action = "<cmd>wincmd ${d.key}<cr>";
      options = {
        inherit (d) desc;
        silent = true;
      };
    }
  ]) directions;
in
{
  config = lib.mkIf cfg.enable {
    keymaps = windowNav ++ [
      {
        # Manual format. Format-on-save is off by §6 row 5 — a silent on-save
        # rewrite corrupts files that must stay byte-exact, and the damage
        # lands in a commit before anyone reads the diff.
        mode = [
          "n"
          "x"
        ];
        key = "<leader>F";
        action.__raw = "function() require('conform').format({ async = true, lsp_format = 'fallback' }) end";
        options = {
          desc = "Format buffer/selection";
          silent = true;
        };
      }
      {
        # Ported from cnixvim as-is. NOTE: this shadows the built-in `gv`
        # (reselect last visual selection). That is ZT's existing behaviour
        # rather than a new decision, so it carries across unchanged and is
        # flagged here instead of being quietly dropped.
        mode = "n";
        key = "gv";
        action = ":!code %<CR>";
        options = {
          desc = "Open in VS Code";
          silent = true;
        };
      }
    ];
  };
}
