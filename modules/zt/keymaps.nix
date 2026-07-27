# Window navigation and the manual-format binding.
#
# Plugin-specific keymaps live with their plugin in ./plugins.nix, so this
# file stays the editor-wide set.
#
# `<leader>` is Space. `modules/core/leader.nix` owns the global and it is live
# on main. (This header used to say cvim set no `mapleader` anywhere; U3 landed
# it afterwards and nobody swept the comments documenting its absence.)
#
# THERE IS NO `<leader>` WINDOW-NAV KEY HERE, and the absence is load-bearing.
# `<leader>h/j/k/l` were dropped 2026-07-27 on ZT's call. A `<leader>` key that
# is also the PREFIX of longer bindings resolves by RELATIVE DEFINITION ORDER,
# not by ambiguity, and both orders fail:
#
#   defined BEFORE its longer siblings  fires at 0 ms and STEALS them.
#     `<leader>l` did this to the ten `<leader>l*` LSP bindings in
#     `modules/lsp/keymaps.nix` — unreachable at any human typing speed, while
#     reading 0 ms in every latency sweep. The symptom is absence, so nothing
#     filed it for as long as it shipped.
#   defined AFTER its longer siblings   waits `timeoutlen`.
#     `<leader>j` paid 1021 ms on every press because `<leader>jv` (videre,
#     ./plugins.nix) is registered first. `<leader>h` did the same inside a
#     hurl buffer, ahead of hurl's buffer-local `<leader>h*` maps.
#
# Diagnosis and the interventions that prove it: `results/cvim-leader-j-delay.md`
# (session 27-07-nvim-distro). Reordering only moves the defect between those
# two rows — measured, not argued. Re-adding any of the four re-creates it.
# `<Left>/<Down>/<Up>/<Right>` and `<S-Left>`… below carry window nav instead,
# so nothing was lost but muscle memory.
#
# Editor-surface states:
#   empty    A window-nav key with no window in that direction is a no-op;
#            vim does not error or wrap.
#   error    `<leader>F` with no conform formatter for the filetype falls back
#            to the LSP (`lsp_format = "fallback"`); with neither, conform
#            reports it in `:messages` and the buffer is untouched.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;

  # Window navigation is the same four directions over three key families, so
  # it is generated rather than written out twelve times. Each entry still
  # carries its own `desc` — U12 asserts that, and a generated keymap without
  # one fails the same as a hand-written one.
  #
  # A fourth family, `<leader>h/j/k/l`, was emitted here until 2026-07-27. Four
  # directions generated uniformly is exactly the shape in which nobody notices
  # that two of the four behave differently — see the header.
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
      # NO `gv` BINDING. cnixvim mapped `gv` to `:!code %` (open in VS Code),
      # shadowing the built-in reselect-last-visual. U9b ported it and flagged
      # the shadowing rather than deciding, which is the only reason it reached
      # ZT as a question; ZT dropped it 2026-07-27. `gv` is the built-in
      # everywhere again — in normal mode and in visual mode.
    ];
  };
}
