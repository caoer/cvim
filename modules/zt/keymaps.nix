# Window navigation, buffer switching, and the manual-format binding.
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

  # ZT's buffer switching, carried over from the previous runtime: `<Tab>` and
  # `<S-Tab>` walk the tab line. Bound here rather than in ./leader-parity.nix
  # because `<Tab>` is not on the leader surface, and not in
  # ../ui/bufferline.nix because it is taste rather than part of what makes the
  # tab line work. `<leader>b]`/`<leader>b[` keep the same two commands.
  #
  # `<Tab>` IS `<C-i>` on the wire — both are 0x09 — so this normally costs the
  # jumplist's forward jump. It does not here, and the reason is the terminal
  # stack, not vim: tmux runs `extended-keys on` with `extended-keys-format
  # csi-u`, and Neovim 0.12 keeps the two as separate entries in the map table.
  # Measured on this build rather than assumed: the CSI-u encoding of Ctrl+I
  # (`ESC [105;5u`) fires the `<C-i>` map, while a raw 0x09 fires this one.
  #
  # The dependency is therefore real and external. Drop `extended-keys`, or
  # open this config in a terminal that does not speak csi-u, and Ctrl+I starts
  # switching buffers instead of jumping forward. That is the trade, and it is
  # invisible from inside the config — which is why it is written down here.
  bufferKeys = config.cvim.ui.enable && config.cvim.ui.bufferline.enable;

  tabCycle = lib.optionals bufferKeys [
    {
      mode = "n";
      key = "<Tab>";
      action = "<cmd>BufferLineCycleNext<cr>";
      options = {
        desc = "Next buffer";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<S-Tab>";
      action = "<cmd>BufferLineCyclePrev<cr>";
      options = {
        desc = "Previous buffer";
        silent = true;
      };
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
    keymaps =
      windowNav
      ++ tabCycle
      ++ [
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
