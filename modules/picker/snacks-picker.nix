# snacks.picker — the general finder.
#
# Sole owner of `plugins.snacks.settings.picker` and `.explorer`. The `ui`
# layer owns the other snacks module keys (image, dashboard, notifier); nix
# merges the attrsets, so the two layers never collide.
{ config, lib, ... }:
let
  cfg = config.cvim.picker;
in
{
  config = lib.mkIf cfg.enable {
    # ripgrep and fd are hard dependencies of this layer, not conveniences,
    # and they are declared here because the alternative failure is silent.
    #
    # Measured on this build before the fix: with `rg` absent from PATH,
    # `Snacks.picker.grep()` renders `0/0` and an empty list — BYTE-IDENTICAL
    # to an honest zero-results search (captures state-a vs state-a2,
    # `diff` reports no difference). snacks' grep source hardcodes
    # `local cmd = "rg"` with no `executable()` guard, so a missing binary
    # produces no error, no notification, and no clue.
    #
    # Nothing about the editor's own PATH saved us here: the nixvim wrapper
    # exports only its ruby env, so `rg` was being inherited from ZT's
    # ambient shell. That works on his mac and silently does not on a bare
    # server profile — the platform this distro actually ships to.
    dependencies = {
      ripgrep.enable = true;
      fd.enable = true;
    };

    plugins.snacks = {
      enable = true;

      settings = {
        picker.enabled = true;

        # `explorer` is OFF by intent, and the `false` is load-bearing rather
        # than decorative: snacks' setup does
        #   `opts[k].enabled = opts[k].enabled == nil or opts[k].enabled`
        # over every key in opts, so merely *mentioning* a module key enables
        # it. snacks.explorer starts a `vim.uv.fs_event` handle per directory
        # it opens (lua/snacks/explorer/watch.lua) and never opens one while
        # disabled. yazi is this layer's file explorer; two explorers would be
        # two answers to one question, and one of them would be watching the
        # filesystem.
        explorer.enabled = false;
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader><space>";
        action.__raw = "function() Snacks.picker.smart() end";
        options.desc = "Find file (smart: buffers + recent + files)";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action.__raw = "function() Snacks.picker.grep() end";
        options.desc = "Grep in project";
      }
      {
        mode = "n";
        key = "<leader>fw";
        action.__raw = "function() Snacks.picker.grep_word() end";
        options.desc = "Grep word under cursor";
      }
      {
        mode = "x";
        key = "<leader>fw";
        action.__raw = "function() Snacks.picker.grep_word() end";
        options.desc = "Grep selection";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action.__raw = "function() Snacks.picker.buffers() end";
        options.desc = "Find buffer";
      }
      {
        mode = "n";
        key = "<leader>fr";
        action.__raw = "function() Snacks.picker.recent() end";
        options.desc = "Find recent file";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action.__raw = "function() Snacks.picker.help() end";
        options.desc = "Find help tag";
      }
      {
        mode = "n";
        key = "<leader>fk";
        action.__raw = "function() Snacks.picker.keymaps() end";
        options.desc = "Find keymap";
      }
      {
        mode = "n";
        key = "<leader>fR";
        action.__raw = "function() Snacks.picker.resume() end";
        options.desc = "Resume last picker";
      }
    ];
  };
}
